# PUF256 整合與實板驗證結果（2026-11-13）

本階段完成獨立 PUF FPGA 套件：實體 RO → counter/CDC → 配對採樣與投票 → helper/ECC → AXI/Jupyter。未連動原 SHA3 專案。Registration 與 Certification（資料重建）的功能模擬及 PYNQ-Z2 實板測試通過。

## 實板結果

環境：PYNQ-Z2 xc7z020clg400-1、PYNQ 2.5、Python 3.6.5、實際 FCLK0=100.0 MHz。Vivado 2026.1 本地建置；每次量測 warmup=1024、window=100000 cycles。

|項目|結果|
|---|---|
|實體 RO / 候選配對|640 / 320|
|參考量測|320×32 = 10240 筆|
|訓練量測|320×128 = 40960 筆|
|符合篩選條件|288 組；依訓練資料排序，凍結其中256組|
|獨立 holdout|256×32 = 8192 筆，0 fault/tie/flip/weak|
|選中配對最小 count margin|training與holdout均為29；核心門檻為8|
|硬體 Registration|成功；256-bit輸出與凍結參考相同，80-bit helper符合獨立 syndrome 計算|
|連續重建|100/100 相同|
|共同 abort/reset 後重建|1/1 相同|
|相同 bitstream 重載後重建|10/10 相同；每次確認輸入/輸出/序號暫存器已清零，再載入外部 bitmap/helper|
|重建合計|111/111 相同，修正區塊總數0|
|原始資料獨立核對|59392筆 CSV、配對排名、bitmap、helper、輸出摘要與序號均通過|
|整段實驗耗時|約284.7秒|

本次實板沒有觀測到需要 ECC 修正的位元錯誤；單位元修正與雙位元拒絕由下列故障注入模擬驗證，不能把乾淨的實板重讀當作所有錯誤分支都已在板上觸發。

實板資料位於 [sample_results/board_20261113](sample_results/board_20261113)。板上時鐘與用戶端不同，因此保留原始資料夾名稱 results_20261112_181403；計時採 monotonic clock。verification.json 是獨立檢查結果，raw_results.zip 是原始匯出檔；clean executed Notebook 保留三個實際執行過的程式 cell 與輸出，原始匯出快照另存供核對。

## 模擬與 FPGA 檢查

|檢查|結果|
|---|---|
|完整 TESTBED + PATTERN|通過；320組真實波形計數、AXI握手、註冊、重建、ECC、弱配對、停振、飽和、abort與全域reset|
|人工 count 核心回歸|通過；包含多數決、錯誤輸入、超時/鎖定/恢復，以及3-bit誤修正限制|
|獨立 ECC|4個乾淨、64個單錯誤、480個雙錯誤案例通過|
|Python 驅動與篩選|7項測試通過；另驗證資料核對器可拒絕錯誤輸出摘要、helper與時脈紀錄|
|100 MHz routed timing|WNS +0.145 ns、WHS +0.061 ns、WPWS +0.500 ns；違反端點均0|
|Gray CDC / bus skew|640組通過；最大3.323 ns，小於8 ns限制|
|CDC / DRC / clock coverage|無critical CDC、severe DRC、missing clock或unconstrained internal endpoint|
|Methodology|234/234完成，無非預期finding；保留RO相關Critical Warning/Warning，並非零警告|
|資源|19958 LUT（37.52%）、49629 registers（46.64%）|

bitmap 組合 popcount 的時序瓶頸已改為多時脈檢查，詳見 [TIMING_CLOSURE.md](TIMING_CLOSURE.md)。methodology分析以178766筆原始default時序紀錄比對，無端點被放寬；分析設定只用於唯讀checkpoint，不用於實作。

## 可重跑的交付內容

- [README.md](README.md)：架構、檔案用途與操作。
- [PATTERN_GUIDE.md](PATTERN_GUIDE.md)：TESTBED/PATTERN階段與波形閱讀。
- sample_results/simulation/waveform_vcd.zip：178個關鍵信號的實際通過波形；解壓後為ro_diag.vcd。
- 04_BOARD：已驗證bitstream/HWH、Python驅動、Notebook與來源manifest。
- sample_results/vivado_2026_1：正式報告、完整methodology證據與實際final_routed.dcp。
- [板端 Notebook](http://140.113.201.80:20100/notebooks/puf256_a0981_20261113/PUF256_Validation.ipynb)：已保存執行結果。

bitstream SHA256：

```text
79346d7855c4a678563e8010083456b762b63bc8a8455388b2c45d4f12b7c7c2
```

請保留此bitstream與其bitmap/helper的配對；重新布局/繞線後重新篩選並註冊。此次只驗證單板、固定bitstream與當時室內環境，未驗證整板冷開機、完整溫壓範圍、跨晶片唯一性或熵。256-bit輸出是PUF資料，尚非已證明具有256-bit安全強度的金鑰；每16-bit區塊的3-bit以上錯誤仍可能誤修正，helper/bitmap也未經認證。
