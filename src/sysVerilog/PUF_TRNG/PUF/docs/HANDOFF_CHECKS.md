# 2026-11-17 交付整理檢查

整理內容為新版來源選定、目錄/路徑、工作站入口、使用文件與證據索引。**正式十個RTL未修改**，逐檔hash與既有上板版一致。沒有自動git add、commit或push。

|本次檢查|結果與範圍|
|---|---|
|正式目標目錄靜態檢查|RTL bytes、三份filelist、Python/Notebook語法、文件連結通過|
|主機測試|20項unittest通過，包括MMIO、篩選、雙板、千次證據檢查|
|Verilator core|重新編譯/執行PASS，包含超時/錯誤/ECC限制|
|Verilator ECC|重新編譯/執行PASS：4 clean、64 single、480 double|
|Verilator完整wave|重新編譯/執行PASS：AXI、全部320配對、真實counter/CDC、PUF/ECC及故障/reset；約17ms模擬時間|
|正式Git Repo含空白路徑|完整wave來源經Verilator translate-only通過；另核對與實際執行的暫存來源逐檔相同|
|Vivado 2026.1 AXI IP打包|實際執行、check_integrity通過|
|Vivado PS7/AXI/PUF Block Design|實際建立/validate/generate_target通過，未launch synthesis/implementation|
|部署準備入口|用原已驗證checkpoint、報告與來源snapshot實際通過，產出bit/HWH/Python/Notebook/MANIFEST|
|歷史證據重算|原routed報告、CSV訓練選樣、共同bitmap111次、各板1000筆重新核對通過，49次拒絕完整保留|
|Git忽略及換行|build/二進位部署檔被忽略；RTL及歷史hash綁定證據禁止換行轉換|
|學校VCS/DC|提供入口；本次沒有工具/製程庫，未實跑|
|整理後完整FPGA implementation/新板測|本次未重跑；歷史已驗證bitstream的成果仍保留|

詳細輸出見 [handoff_20261117](results/handoff_20261117)。模擬在暫存目錄重新編譯/執行，然後核對安裝目錄所有filelist來源相同；不是將舊二進位冒充新測試。工作站可依sim/README重跑VCS。

首次Windows編譯在受限環境寫入Zig快取失敗，改用短輸出根及可寫入的編譯環境後通過，沒有修改RTL來迴避。完整wave未開VCD；若需波形可依模擬文件重跑--vcd。

Vivado打包/BD有保留vendor warnings，包括SystemVerilog top打包提醒、board preset DDR參數及hook未加入utils fileset等。此次通過僅表示該入口與BD生成完成，不等於新implementation或板上DDR已驗證。完整建置仍需依FPGA_BUILD的最後gate檢查。

原src/puf全目錄（包括舊.build）另存工作區備份；Git內歷史快照只包含必要來源/文件與小型證據。備份位置見本次工作區puf_install_receipt_20261117.json。其他SHA3目錄未改動。

## 測試名稱後續調整

本頁上面的回歸紀錄使用更名前的測試名稱。現在的入口與本次改名檢查請看 [TEST_NAMING](TEST_NAMING.md)，歷史原始紀錄不改寫。
