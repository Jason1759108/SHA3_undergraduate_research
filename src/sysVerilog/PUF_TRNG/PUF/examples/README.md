# 整合範例入口

AXI整合的完整可執行範例就是 `scripts/vivado/build.tcl` 與 `rtl/puf_fpga_top.sv`；原生量測/PUF連接可看 `rtl/puf_axi.sv` 的u_device與u_measure。避免維護第二份容易與正式RTL脫節的複製top。

請讀 [INTEGRATION](../docs/INTEGRATION.md) 的握手、timeout與資料順序。SHA3串接目前只有契約說明，沒有實作adapter或通過整合測試。
