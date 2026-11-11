# 第二階段：歷史比較基準與熵評估工具

現行版本請看 [stage3_health](../stage3_health/README.md)。本階段的舊 RTL、GUI 工程、早期參數掃描、測試用 notebook 與重複資料已移除，不再作上板入口。

只保留：

- captures/board_21600/assessment_20261111：第二階段約 6.646975 bits/八路樣本的原始統計紀錄、NIST 日誌與摘要。
- 該目錄中 datasets/raw_joint_concat.bin：1,024,000 bytes 基準資料，仍由第三階段 sim/check_policy.py 使用，並可按每批 1024 點重建分批原始樣本。
- build/nist_native：目前評估程式仍使用的兩個凍結執行檔、建置來源與 Windows 相容 patch；移除編譯物件與重複來源副本。
- references/tool_sources：三個外部專案的固定 revision、來源網址與原始授權/說明。
- references/neoTRNG_upstream：曾引用的開源方法來源與原始授權；未加入現行 RTL。
- docs/ENTROPY_STAGE_EXIT_CRITERIA.md：原先階段判據，作歷史設計依據。

原始 NIST 與相依套件的完整 checkout 已依使用者確認移除；重新編譯時須依 references/tool_sources/sources.lock.json 取得指定來源。兩個已驗證的 Windows 執行檔仍保留，執行所需 MSYS2 MinGW/OpenSSL 環境不隨此資料夾提供。Linux 可使用相同 NIST 來源自行建置。Windows seed 相容修改詳 build/nist_native/windows_seed.patch，並非 NIST 對本設計認證。

歷史報告描述的是當時操作；其中已移除的舊 GUI/資料解壓工作目錄不再保留。現在只維護最新健康監測版與必要比較證據。
