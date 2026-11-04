# 四版正式程式

`V0_C3_NoFT`、`V1_State1600_SECDED_Replay`、`V2_Lane64_SECDED_Replay`、`V3_LaneParity_LocalReplay` 是 2026-11-04 工作站驗證所用的 overlay。四版均有完整 01 RTL `PASS`、10 ns 02 `OK`、03 `PASS_WITH_SDF_WARNING` 的精簡結果。結果檔在 `../工作站結果/2026-11-04_四版10ns/`。

工作站操作及保存規則見 [PROJECT_10NS_GUIDE.md](PROJECT_10NS_GUIDE.md)。`SERIAL320_four_compact.zip` 由 `package_four.py` 產生，是這四個資料夾的傳輸包。四版是 build 專案的 overlay，並非完整製程庫或已 build 的工作站專案。
