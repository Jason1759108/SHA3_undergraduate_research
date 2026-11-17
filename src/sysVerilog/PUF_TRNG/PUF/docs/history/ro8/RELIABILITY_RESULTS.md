# RO 實板重複性測試

本階段已完成，結果 **PASS**。8 組配對共 10,560 筆量測，與先前保存的參考位元相比，翻轉、平手、故障均為 0。測試使用同一塊 PYNQ-Z2（Jupyter port 20100）、同一份已部署 bitstream，沒有修改 RTL 或重新建置。

## 方法與判定

- 初始載入後，各組量測 1,000 次，共 8,000 筆。
- 再重新載入相同 bitstream 10 回合，每回合各組量測 32 次，共 2,560 筆。
- 每組合計 1,320 次。所有回合固定 warmup 1024 cycles、window 100000 cycles（1 ms）。
- 參考位元固定為 pair 0 到 7 的 `1,0,1,1,0,1,0,0`，取自前一批 256 筆實板 CSV；沒有以本次多數決重新定義答案。
- 每次載入均檢查 bit/hwh SHA256、硬體 sequence=0 與 FCLK0=100 MHz。紀錄共 11 次載入，包含初始載入和後續 10 回合。
- 只有完整取得 10,560 筆、無翻轉／平手／故障、無例外、成功停用所有 RO，才顯示 PASS。

## 結果

| Pair | 參考位元 | 初始讀取 | 重載後讀取 | 翻轉 | 平手 | 故障 | 最小絕對計數差 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 1 | 1000 | 320 | 0 | 0 | 0 | 144 |
| 1 | 0 | 1000 | 320 | 0 | 0 | 0 | 387 |
| 2 | 1 | 1000 | 320 | 0 | 0 | 0 | 194 |
| 3 | 1 | 1000 | 320 | 0 | 0 | 0 | 192 |
| 4 | 0 | 1000 | 320 | 0 | 0 | 0 | 67 |
| 5 | 1 | 1000 | 320 | 0 | 0 | 0 | 843 |
| 6 | 0 | 1000 | 320 | 0 | 0 | 0 | 59 |
| 7 | 0 | 1000 | 320 | 0 | 0 | 0 | 95 |

計數差單位為除以 8 後的 ticks。Pair 6 在本批最接近比較邊界，但仍未跨越 0；不能只憑本批資料決定未來環境條件下的可靠性。所有 A/B 頻率估計範圍為 175.824–184.808 MHz。板上 monotonic 紀錄整個測試約 29.50 秒，這是短期重複與重配置測試。

本機已另行檢查完整 CSV：筆數、每回合／配對樣本數、序號、count 差值、頻率換算、固定參考位元，以及所有摘要統計均一致。瀏覽器檔案下載逾時，因此改由 Notebook 顯示已保存的 CSV／JSON，再保存頁面文字；CSV 換行還原為 CRLF 後，SHA256 與板上原始檔完全相同。

CSV SHA256：`488dd5c1479a0808a8d68167b288b8ca32dd24553db4859ef69b36dad28483c6`。

## 檔案與重現

- [原始 CSV](sample_results/reliability_20100/measurements.csv)
- [板上摘要](sample_results/reliability_20100/summary.json)、[測試參數](sample_results/reliability_20100/protocol.json)
- [本機核對結果](sample_results/reliability_20100/verification.json)
- [Notebook 完成畫面](sample_results/reliability_20100/jupyter_reliability.png)
- [重跑用 Notebook](05_RELIABILITY/RO_Reliability_1000.ipynb) 與 [原始量測程式](05_RELIABILITY/ro_reliability.py)
- [已執行的板上 Notebook](http://140.113.201.80:20100/notebooks/ro_diag_a0981_20261106/RO_Diagnostic.ipynb)：新增的 In[11] 為量測，In[12] 為圖表／匯出，In[13] 為保存結果的文字顯示。

板上本次目錄：`results/reliability_20261106T034040Z_27554aeb/`。內含 CSV、JSON、圖表與結果 ZIP。板上時鐘與用戶端不同，檔名不代表精確實際日期；每筆 elapsed_s 使用 monotonic 時間。

若要在相同板子重跑，將 `05_RELIABILITY/RO_Reliability_1000.ipynb` 和 `reference_measurements.csv` 放到與 `04_BOARD/ro_diag.bit`、`ro_diag.hwh`、`ro_diag.py` 相同的 Jupyter 目錄。Notebook 每次建立新的結果資料夾。原始 `.py` 保留本次實際執行時使用的舊參考 CSV 路徑；重跑用 Notebook 改用同層的 reference_measurements.csv，內容為同一份已保存的參考。

## 結論範圍

已確認此 8-pair 配置在本批短期讀取與相同 bitstream 重配置後重現參考位元，最後所有 RO 已停用。沒有實際斷電、控制溫度／電壓、跨板唯一性或熵測試；0 次觀測翻轉不代表真實誤碼率為 0。尚未接入 Bitmap、ECC、helper、SHA3 或產生 PUF 金鑰。

下一階段可先擴充到 32 組配對，重新做佈局／時序與實板量測，再依資源與穩定性評估擴充到 320 組、選取 256 組的可行性。
