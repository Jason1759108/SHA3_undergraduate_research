# Vivado 入口

從 `src/sysVerilog/PUF_TRNG/PUF` 執行 `vivado -mode batch -source scripts/vivado/build.tcl`。完整環境、部署與風險見 [FPGA_BUILD](../../docs/FPGA_BUILD.md)。

本目錄包含 IP 包裝、PS7/AXI Block Design、RO 位置/時脈/Gray CDC 約束、報告配置、routed 匯出、methodology 分析、部署檔準備，以及 resume/recovery 腳本。保留相互依賴，不能只拷貝 build.tcl。

`board_files/SOURCE.json` 記錄 PYNQ-Z2 board preset 來源。`ro_constraints.tcl` 要在 synthesis linked netlist 後、opt_design 前執行；層級/RO 數量/BEL 變更時會拒絕，不應移除斷言以繞過錯誤。

resume.tcl、finish_from_physopt.tcl 僅用於明確匹配的未完成建置；正常重現先使用 build.tcl。
