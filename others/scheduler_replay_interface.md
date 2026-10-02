# Scheduler replay 接線合約

本文件補充 Person A Phase 3 的 `keccak_round_scheduler.sv`。不修改 Person B 的 θ／χ，也尚未整合 top。

## 訊號與時序

| 訊號 | 來源 → 目的 | 意義 |
| --- | --- | --- |
| `fault_valid`, `replay_kind` | region → scheduler | 當拍的不可修正錯誤與建議重算類型 |
| `theta_hold`, `chi_hold` | scheduler → θ／χ（需新增接線） | 出錯當拍保留／保存出錯 index，禁止正常前進 |
| `theta_replay`, `chi_replay` | scheduler → θ／χ | 下一拍的一拍 replay 命令 |
| `active_replay_kind` | scheduler → θ 的 `replay_kind` | 已鎖存的命令類型，不能改接 region 當拍的組合輸出 |

- Cycle T：接受正確 phase 的 fault，拉高對應 `hold`，鎖存 `replay_kind`。即使 `done=1` 也不轉移階段、不增加 round。
- Cycle T+1：對應 `replay=1`，`start` 不重發，`active_replay_kind` 保持原本命令。忽略此拍 `done`。
- Cycle T+2 起：`replay=0`。θ／χ 繼續執行，完成時須重新送出 `done`。scheduler 不把出錯拍的舊 `done` 當成完成。
- `FROM0` 使用一拍命令讓 θ 自己重算 C/D 並重新走 col0～4，不持續拉高 replay，避免反覆把 θ 重設回 col0。
- 所有命令也在 `SCHED_*_START` 接受，涵蓋 col0／row0 錯誤。

## Person B 必須配合的項目

1. 現有 θ／χ 僅在 `replay=1` 時 hold index，無法直接接收「下一拍 replay」而保留出錯位置。需加入出錯當拍的 `hold` 控制，或保存失敗操作的 index。`hold` 只影響更新，不能改變當拍的 fault 檢查資料，避免組合回授。
2. 起始拍出錯時，replay 沒有 `start`。χ 必須能單靠 replay 重算 row0 並在之後正常進入 row1；θ 的 col0 replay 也必須能繼續進入 col1。
3. 重算必須使用該操作原本的輸入。只 hold index 不足以保護已部分寫回的 state。θ 的 XOR 不能套用到已更新的 lane；FROM0 也不能直接用部分 θ 更新後的 state 當成原始 state。χ row0 必須保留需要的原始 row0 輸入，row1～4 不可重鎖 frozen_state。
4. 最後一欄／列在 replay 期間 `done=0`，結束後須有可被 scheduler 接受的完成訊號。不能直接回 IDLE 而遺失 done，也不能為了重新拉 done 又寫入一次相同操作。
5. `src` 要依當前運算決定，不能只在 lane 發生 UNCORR 時才設定，否則只有 D 出錯時會漏掉 recovery。
6. 新增輸入正式接線前應明確綁定為 `fault_valid=0`、`replay_kind=FT_REPLAY_NONE`。不要把未接線輸入當成關閉 FT 的正式方案。

## 重試界線與驗證範圍

依「同一 round 最多一次注入」合約，`replay_used` 每 round 只允許一個 replay 命令，在正常 χ 完成、進入下一 round 時清除。第二次 fault 仍可由 region 拉 `fault_valid` 供記錄，但 scheduler 不再重試、不阻擋新的 done。這是避免卡死的上限，不保證重複 fault 下 hash 正確。

無 fault 時保留原本 10 cycle/round、240 cycle 的排程。replay 的總延遲與 hash 正確性仍須整合 θ／χ、原始輸入保存和 state-bank 寫入控制後驗證；scheduler 單元測試不能證明資料路徑 recovery 正確。
