# 直接上板步驟

## 1. 準備與上傳

1. 先確認登記使用的板號與遠端網址一致，並確認目前沒有其他人使用。
2. 在 Windows 解壓 `delivery/trng_integrated_ready.zip`。八個檔案必須全部使用同一包，不要和舊版 SHA3 或健康來源的檔案混放。
3. 開啟該板子的 Jupyter 檔案頁。右上 **New → Folder** 建立新資料夾，例如 `113511153_TRNG_integrated`。勾新資料夾後按 **Rename** 可改名，再點資料夾名稱進入。
4. 按右上 **Upload**，選取解壓後八個檔案；若頁面顯示各檔案的藍色 **Upload**，逐一點擊完成。

八檔為 `trng_sha3.bit`、`trng_sha3.hwh`、`trng_sha3.py`、`trng_health.py`、`trng_pynq.py`、`trng_collect.py`、`TRNG_Integrated_Bringup.ipynb`、`release_manifest.json`。

`.bit` 是 FPGA 設定電路；`.hwh` 是這份電路的介面與位址說明；`.py` 是板上操作程式；`.ipynb` 是逐格操作本；manifest 是配對版本與檔案指紋。Notebook 會自動儲存輸出，因此它不列入不可修改的六檔指紋。

## 2. 由上往下逐格執行

1. 雙擊 `TRNG_Integrated_Bringup.ipynb`。每次點程式格，再按 **Shift+Enter** 執行並移到下一格。
2. 匯入格應顯示 PYNQ 2.5、Python 3.6.5 與 `kernel OK`。如果連這格都停住，不要執行後面的硬體格。
3. 離線檢查格應正常印出 build_id、25 MHz、未認證等資訊，沒有 traceback。此時尚未設定 FPGA。
4. 填正確板號與**實際操作日期**，日期格式 `2026-11-16` 這樣的 YYYY-MM-DD。不要保留提示文字，也不要照抄錯誤的板上時間。
5. 執行載入格。應顯示只下載一份整合電路、25 MHz ready，初始狀態與 RO enable 都為零。不要同時開舊版操作本載入其他電路。
6. 執行 SHA3 格。應顯示 **34 次 PASS**，涵蓋空訊息、abc、區塊邊界與長訊息。
7. 執行 16 批格。摘要應為 `PASS_FUNCTIONAL`、completed_batches=16、raw_bytes=16384、digest_bytes=512、all_hardware_digests_match_python=true、health_faults=0。健康狀態應為 status=194、count=1024、observed=2048、startup_seen=1024、RO=0、各故障遮罩=0。
8. 上一格成功才執行 1000 批格。每 16 批會更新進度；完成應為 completed_batches=1000、raw_bytes=1024000、digest_bytes=32000。這是新資料收集，尚未執行 NIST 熵評估。
9. 執行安全結束格。兩個 `DMA halted` 應都是 True，RO enable=0。這格會先停止硬體，確認後才釋放傳輸記憶體。

## 3. 下載並交回

1. **Ctrl+S** 儲存本次輸出。
2. 左上 Jupyter 圖示回到檔案頁，進入 `trng_results`。
3. 下載本次 16 批與 1000 批各自產生的 ZIP。一次只勾一個 ZIP，再按 **Download**。不要逐一下載裡面的子資料夾。
4. 在操作本選 **File → Download as → Notebook (.ipynb)**，下載有執行結果的操作本。
5. 提供這兩個 ZIP 和 Notebook，接著才能核對實板結果、對新布局原始資料重跑熵估計與重啟評估。

## 4. 如果出錯

立刻停在該格，保留完整 traceback 與已產生的 ZIP。程式不會自動忽略失敗批次、重試補資料或把舊摘要當新結果。

若介面仍能回應，可執行最後的安全結束格。若停止也失敗，保留工作狀態並交管理員／我們診斷，不要反覆 Run All、重新載入 FPGA 或建立多個 Session。軟體逾時保護需要底層 MMIO 仍會回應；無法保證處理器或網路本身卡住時仍能中斷。

程式有明確的 `session.recover()`，它會先確認 RO 關閉與兩個 DMA 都停止，再重新載入整份電路；這是診斷後使用的復原功能，不是健康失敗後自動繼續收集的捷徑。
