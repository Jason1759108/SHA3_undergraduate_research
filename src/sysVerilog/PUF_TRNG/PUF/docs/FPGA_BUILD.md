# PYNQ-Z2 FPGA 重現

已驗證硬體平台：xc7z020clg400-1 / PYNQ-Z2，Vivado 2026.1，100 MHz FCLK0。板端 PYNQ 2.5 / Python 3.6.5；其他版本需重新檢查，不能直接套用過去結果。

## 從來源建置

從 `src/sysVerilog/PUF_TRNG/PUF`：

```sh
vivado -mode batch -source scripts/vivado/build.tcl
```

Windows 建議設短輸出路徑，例如 PowerShell `$env:RO_DIAG_BUILD_ROOT='C:/puf_build'`。可用 RO_DIAG_JOBS 指定平行工作數；Windows 2026.1 methodology 分析另需 RO_DIAG_PYTHON 指到 Python 3.11+。未設輸出根時在 `build/vivado_<timestamp>/`。

腳本先 package `puf_fpga_top` 成 user.org:user:puf256:1.0，再建立 PS7/AXI/reset/PUF IP。AXI 預設 0x43C00000、4KiB；driver 從 HWH 取得實際 IP。board preset 隨來源提供。

不得省略 RO placement、每 RO 2ns 工程時脈上限假設、Gray CDC max-delay/bus-skew 約束或報告檢查。實測頻率仍需落在假設內；時序工具不會預測真實振盪頻率。

## 檢查與部署

建置會留下 final_routed.dcp、timing/CDC/DRC/skew/utilization 報告，完成全部 methodology；bit/HWH 匯出到 `deploy/<timestamp>/`。匯出二進位不等於所有檢查完成，準備部署前需最後 gate：

```sh
python3 scripts/vivado/prepare_deployment.py --build build/vivado_<timestamp> --deploy deploy/<timestamp>
```

它核對 routed 報告、234 項 methodology 完成/非預期 finding、checkpoint hash，以及 Vivado 匯入的十個 RTL snapshot 與當前來源相同，才建立 `build/board_upload/`。將該目錄內容上傳至自己的獨立 Jupyter 資料夾，執行 PUF256_Validation.ipynb。

部署檔包括成對 `puf256.bit/puf256.hwh`、Python driver/程式、Notebook 和 MANIFEST。PYNQ 要求配對硬體描述；參考 [PYNQ 官方 Overlay 文件](https://pynq.readthedocs.io/en/v3.1/pynq_libraries/overlay.html)。不要混用不同建置的 bit/HWH。

## 原結果與重新整合

原 bitstream hash 與結果在 [SOURCE_MANIFEST](SOURCE_MANIFEST.json)、[VALIDATION](VALIDATION.md)。此次路徑整理不代表已重新跑完整 Vivado implementation；實際新檢查紀錄見 HANDOFF_CHECKS。

RO 警告保留嚴重度，不能全域降級。Windows 2026.1 的 57 項 Timing methodology 使用原/default 與替代分析的逐 endpoint 保守核對，只作用於唯讀 checkpoint，沒有套到 synthesis/place/route/bitgen。其程式在 verification，詳見 [TIMING_CLOSURE](TIMING_CLOSURE.md)。其他 OS/版本先走原生 methodology，勿任意套內部設定。

修改 top、階層、RO 數量、器件或加入 SHA3 等模組，皆需重新檢查布局資源與約束匹配。此次 constraint 固定部分位置，沒有固定所有 routing；即使 RTL 不變，重新繞線也可能改變 PUF 指紋。新 bitstream 應重新篩選/註冊，不沿用歷史 bitmap/helper。

## 僅產生整合用IP或驗證BD

設定環境變數 `PUF_PACKAGE_ONLY=1` 可只打包AXI IP到建置目錄的ip_repo，供其他專案加入IP Repository。設定 `PUF_PACKAGE_ONLY=0`、`PUF_BD_ONLY=1` 可只建立/驗證PS7與AXI Block Design；兩者預設不啟用。正式完整建置請清除這兩個環境變數。這些檢查都不代表implementation通過。
