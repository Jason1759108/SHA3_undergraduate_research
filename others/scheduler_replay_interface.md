# Parity + Replay 接線合約

現行 RTL 使用代數 parity detection，不再使用 SECDED status 或 replay kind。
完整公式與故障模型見 [parity_predictor_design.md](parity_predictor_design.md)。

| 訊號 | 來源 → 目的 | 意義 |
|---|---|---|
| `predicted_parity` | θ／χ predictor → checker | 從運算前輸入得到的每 lane 預期 parity |
| `checkpoint_fault` | θ → checker | col0 的任一 C parity 不符，C checkpoint 不得接受 |
| `fault_valid` | checker → scheduler | active lane parity 或 C checkpoint 檢查失敗 |
| `theta_hold`, `chi_hold` | scheduler → θ／χ | 出錯當拍維持運算索引，不接受 done |
| `theta_replay`, `chi_replay` | scheduler → θ／χ | 前一拍失敗，當拍使用原始輸入再次運算 |

1. Cycle T 偵到錯誤：整欄／整列保留 state，hold 索引，不增加 round。
2. Cycle T+1 replay：重新檢查。通過就提交整個操作並前進；失敗仍 hold，T+2 再 replay。
3. 每次 fault 都接受，包括 replay 當拍、同一 round 的第二次 fault、最後 col／row。沒有重試上限；永久 fault 會停滯，不能放行錯誤 digest。
4. start 僅發一次。θ 的 col0 失敗時原始 state 尚未修改，因此重新計算 C；C 與獨立 cP 必須全部驗過且 col0 通過才一起提交。後續 col 用已保存的 C 重算 D。
5. χ 在 start 保存完整 rho/pi 結果，replay 不可重鎖成部分更新過的 state。
6. 最後 col／row 的 replay 若當拍通過，可以同拍接受新 done；fault 當拍絕不可接受 done。
7. hold 只影響暫存器更新與 done，不影響當拍檢查的資料或 active mask，避免組合回授。

正常核心排程仍為 10 運算拍／round、240 運算拍／permutation。
TB 含 start_process 交握的計數為 241；每個偵到錯誤而失敗的拍增加一拍。
