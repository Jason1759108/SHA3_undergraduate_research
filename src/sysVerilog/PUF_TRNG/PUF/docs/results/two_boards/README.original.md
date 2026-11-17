# PUF256 雙板測試套件

測試日期（本地）：2026-11-13。第一板 `20100`，第二板 `20200`。獨立存放，未修改 SHA3 專案或原單板建置。

**同一份 bitstream、同一份凍結 bitmap，兩板硬體實際輸出相差 72 / 256 bit（28.125%）。但共用 bitmap 在第二板的零拒絕可靠度檢查未通過。** 詳細結果見 [RESULTS.md](RESULTS.md)，全部原始資料在 `sample_results`。

| 測試 | 20100 | 20200 |
|---|---:|---:|
| 各自挑選 bitmap 的基準重建 | 111/111 成功 | 111/111 成功 |
| 相同 bitmap 的重建嘗試 | 111/111 成功 | 62/111 成功，49 次 WEAK_PAIR |
| 成功交易產生不同於本板註冊碼的輸出 | 0 | 0 |

## 檔案

- `04_BOARD`：原單板七個上傳檔案與 MANIFEST；bit/HWH 完全相同。
- `04_BOARD/frozen`：共用 bitmap 與兩板各自的訓練參考值。
- `04_BOARD/20100`、`04_BOARD/20200`：各板補充檔案；上傳至各自與原七檔相同的資料夾。
- `03_NOTEBOOK`：板端程式、Notebook 原始碼；`characterize_common.py` 是保留嚴格失敗後繼續固定測試排程的診斷程式。
- `00_VERIFY`：離線 CSV、選樣、helper、輸出摘要與交易順序檢查；六個 synthetic protocol 測試不是硬體測量資料。
- `sample_results/baseline_*`：各自 bitmap 基準。
- `sample_results/common_20100`：第一板共同 bitmap 完整成功紀錄。
- `sample_results/common_20200_strict`：第二板第一次拒絕即停止的原始資料及後續單配對診斷。
- `sample_results/common_20200_characterized`：原樣保留上述失敗前綴，接續完成固定 111 次嘗試，所有拒絕均保留。
- `sample_results/two_board_comparison.json`：離線核對的實際結論；`comparison_verified=true`，`passed=false`，`all_transactions_successful=false`。

## 板端查看

兩板的資料夾名稱均為 `puf256_compare_a0981_20261113`。

- [第一板共同 bitmap 原始測試](http://140.113.201.80:20100/notebooks/puf256_compare_a0981_20261113/PUF256_Common_20100.ipynb)
- [第二板共同 bitmap 原始測試與失敗診斷](http://140.113.201.80:20200/notebooks/puf256_compare_a0981_20261113/PUF256_Common_20200.ipynb)
- [雙板比較摘要](http://140.113.201.80:20200/notebooks/puf256_compare_a0981_20261113/PUF256_Two_Board_Comparison.ipynb)

比較摘要 Notebook 只讀取已核對的匯總 JSON，不載入 FPGA；實際硬體測量由各板 Common Notebook 完成。重新執行 Validation/Common Notebook 會重新載入 FPGA，並建立新時間戳結果資料夾。Common 嚴格模式遇拒絕即停止，第二板目前可能再發生拒絕。

## 離線重現

使用主機 Python 3.8 以上，從本套件目錄執行（不需要連板）：

```powershell
python 00_VERIFY/compare_boards.py freeze --a sample_results/baseline_20100/results_20261112_181403 --b sample_results/baseline_20200/results_20261112_235911 --out regenerated_frozen
python 00_VERIFY/compare_boards.py verify --a sample_results/common_20100/common_20100_20261112_220713 --b sample_results/common_20200_characterized/characterized_20200_20261113_001833 --plan 04_BOARD/frozen/common_bitmap.json --refs 04_BOARD/frozen --allow-rejections --save recomputed_comparison.json
python -m unittest discover -s 00_VERIFY -p test_comparison.py -v
```

`--allow-rejections` 允許核對「有完整保留拒絕的量測紀錄」，不把拒絕當成功，結果仍為 `passed=false`。不帶此選項會直接拒絕第二板紀錄。命令正常結束代表紀錄通過一致性檢查，需另外閱讀 JSON 的測試結論。

`sample_results/*/raw_results.zip` 與 export snapshot 保留原始匯出。整理後的 executed Notebook 僅移除一個未執行的暫時匯出 cell；第二板預期的 RuntimeError、診斷與後續量測輸出均保留。板上時鐘與本地時間不同，因此原始資料夾日期不改名。原建置與 RTL 可參考相鄰原單板套件 `pynq_z2_puf256`。
