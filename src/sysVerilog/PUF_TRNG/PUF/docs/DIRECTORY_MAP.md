# 目錄與版本對照

此次不是純改名：正式來源更新到已上板驗證的 `pynq_z2_puf256`，再整理路徑。舊專案完整可用來源/文件快照位於 [legacy_ro_integration](history/legacy_ro_integration)，原名與原內容不變；該快照不參與正式編譯。

|舊位置|正式位置|處理|
|---|---|---|
|原專案 `00_TESTBED/`|`docs/history/legacy_ro_integration/00_TESTBED/`|封存；新版 sim 不混用舊模型|
|已驗證套件 `00_TESTBED/`|`sim/`、`verification/`|模擬與主機/報告核對程式依用途分開；依賴路徑同步更新|
|原專案 `01_RTL/`|`docs/history/legacy_ro_integration/01_RTL/`|封存；同名檔也可能與新版不同|
|已驗證套件 `01_RTL/`|`rtl/`|十個檔案逐位元組相同，來源 hash 可核對|
|原專案 `02_SYN/`|`docs/history/legacy_ro_integration/02_SYN/`|保留舊腳本，不能當新版正式入口|
|新增 DC 數位入口|`scripts/synthesis/syn_puf.tcl`|支援 puf_device/puf_core/puf_sketch；需學校 .db 與實跑|
|已驗證套件 `02_VIVADO/`|`scripts/vivado/`|整組搬移，包含 RO 約束與 board files|
|已驗證套件 `03_NOTEBOOK/`|`software/`、`software/notebooks/`|部署時自動複製到同一板端目錄|
|已驗證套件 `04_BOARD/`|`build/board_upload/`|由部署準備腳本產生；不維護第二份正式 Python 來源|
|舊 README_RO/WAVEFORM_RO/VALIDATION_RO|`docs/history/legacy_ro_integration/`|舊版原文，保留日期與範圍|
|正式使用文件|根 README、docs、各入口 README|統一新版操作方法|
|單板/雙板/千次結果|`docs/results/`|原始證據不改寫；總結見 VALIDATION|
|.build、快取、大波形|不納入交付|原工作區外部備份保留；Git 忽略|

舊 `filelist_count.f` 對應舊架構，新版 count 測試叫 `filelist_puf_core_count.f`。舊完整波形路徑使用 `ro_array_model.sv`；新版完整路徑使用新版 `ro_wave_model.sv`，不是任意改名或漏檔。

舊 `02_SYN/syn.tcl` 原為 SHA3；舊 `syn_puf_ro.tcl` 對應舊數位 top。它們保存在歷史快照，不可用來宣稱新版已 DC 合成。

歷史資料內的路徑/指令/hash 保留原貌，僅供追溯。`RESULTS.original.md`、`README.original.md` 不是新的操作入口。

正式測試的後續改名見 [TEST_NAMING](TEST_NAMING.md)；其中歷史00/01/02的原名仍保留。
