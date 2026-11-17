# 2026-11-17 測試命名調整

目的：看到檔名就能知道測試範圍。這次只改正式sim的檔名、module/top與引用/波形輸出名稱，不修改正式RTL、測試刺激或預期判斷。舊版歷史快照、原實板資料與先前回歸紀錄不改寫。

|原檔名|新檔名|
|---|---|
|TESTBED.sv|TESTBED_PUF_AXI_RO.sv|
|PATTERN.sv|PATTERN_PUF_AXI_RO.sv|
|TESTBED_PUF_COUNT.sv|TESTBED_PUF_CORE_COUNT.sv|
|PATTERN_PUF.sv|PATTERN_PUF_CORE_COUNT.sv|
|TESTBED_ECC.sv|TESTBED_PUF_ECC_SECDED.sv|
|PATTERN_ECC.sv|PATTERN_PUF_ECC_SECDED.sv|
|filelist.f|filelist_puf_axi_ro.f|
|filelist_core.f|filelist_puf_core_count.f|
|filelist_ecc.f|filelist_puf_ecc_secded.f|

舊module TESTBED_CORE改為TESTBED_PUF_CORE_COUNT，讓top與檔名一致。其餘module也與新檔名一致。實例路徑仍保留dut/pattern/u_PATTERN等既有名稱，降低波形觀察差異；最上層改為新的TESTBED名稱。

AXI_RO代表含AXI與RO波形的完整路徑；CORE_COUNT代表人工count後端；ECC_SECDED代表獨立錯誤修正單元。它們是模擬模式，不是額外的硬體command。

Makefile、新舊CLI別名、filelist、dumpvars、VCD名稱、波形壓縮器階層過濾與測試指南一併更新。canonical命令請看 [sim/README](../sim/README.md)。

原2026-11-17目錄整理與板測證據見HANDOFF_CHECKS/VALIDATION；本次改名檢查另存 `docs/results/test_naming_20261117/`，不把舊回歸當成本次重新執行。

## 本次檢查結果

- 核心/count、獨立SECDED：新名稱重新編譯並執行通過。
- AXI/RO完整整合：新名稱完成Verilator翻譯/elaboration；這次未重跑完整波形回歸。六個SV反向名稱比對證明刺激與判斷未變。
- 新頂層VCD階層過濾煙霧檢查、filelist/文件連結/語法檢查通過。
- 正式RTL與歷史資料逐檔hash維持相同；學校VCS未實跑。
