# 工作站 Design Compiler：數位核心合成

此為整理時新增入口，尚未在學校 DC 與製程 library 上實跑。不能將提供腳本或 Verilator 測試通過寫成 DC mapped synthesis PASS。

預設 top `puf_device`，讀入 puf_types、puf_sketch、puf_core、puf_device。量測後端以 req/ready/valid/count/status 介面表示，所有介面信號視為 clk-domain 輸入。這驗證數位控制/投票/helper/ECC 的合成，不產生實體 RO。

```sh
cd src/sysVerilog/PUF_TRNG/PUF/scripts/synthesis
TARGET_LIBRARY='/actual/path/slow_corner.db' dc_shell -f syn_puf.tcl
# 可選：PUF_SYN_TOP=puf_core 或 puf_sketch；CLK_PERIOD=10.0 (ns)
```

`TARGET_LIBRARY` 是 Tcl list；庫路徑含空白時需 Tcl 大括號分組。額外 link 庫可用 LINK_LIBRARY 指定。需要真實且有授權的標準元件 .db；不包含學校私有製程庫。腳本不讀舊 02_SYN。

輸出在 `build/dc/<top>/<timestamp>/`：mapped .v、.ddc、.sdc、precheck/check_design、check_timing、area、max/min timing、constraints、references 報告。`RUN_COMPLETED.txt` 僅表示命令完成，需檢查 unresolved/unmapped references、latch、unconstrained endpoints、timing/constraint violations；報告審查後才能記錄該 library 下的結果。

10ns/0.1ns uncertainty/20% I/O delay/0.05 output load 是可重現範例預算，不是學校製程 signoff。需依實際整合環境調整 I/O 驅動與負載、reset recovery/removal 與時序條件。puf_sketch 為組合電路，使用 max-delay 預算。

完整 `puf_fpga_top` 包含 Xilinx LUT RO，應走 Vivado。若要 ASIC 實體 RO，必須另外提供 standard-cell RO、物理布局/CDC/時序流程，不在本入口範圍。
