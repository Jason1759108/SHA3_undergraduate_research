# 方法與開源來源

本階段的三個 SystemVerilog 檔與 AXI 控制/擷取程式是為本專案撰寫，沒有將上游 TRNG 的認證、效能或熵品質結果套用到本設計。它是 RO 候選熵源的量測原型，尚未包含正式健康測試、熵估計與 SHA3 後處理。

## 可直接閱讀的開源專案

- neoTRNG：https://github.com/stnolting/neoTRNG 。作者提供完整 VHDL 熵源及後處理；也明確區分實體振盪與數位模擬模式。原始版本 c688149f70fbd582eac1029cbfec4fcf97b719b2 已保存在 neoTRNG_upstream，含未修改的 LICENSE（BSD 3-Clause）、neoTRNG.vhd 與來源雜湊 SOURCE.json。只供學習，沒有加到本次 Vivado sources。
- OpenTRNG hardware：https://opentrng.org/docs/hardware.html 。說明數種 RO 架構與在 FPGA 上以 LUT 建立振盪器的方法；可從頁面連至上游實作。這次沒有直接拷貝或編譯其程式。

本次選擇保留 8 路各自的原始位元，方便辨識某路停住或路間相關；不先 XOR、去偏或雜湊。奇數級 RO 是常見物理雜訊來源候選架構，不代表任意放上 FPGA 都自然具有足夠熵。接線、擺放、取樣間隔、耦合與工作條件都會影響結果。

## 官方參考

- AMD ASYNC_REG： https://docs.amd.com/r/en-US/ug912-vivado-properties/ASYNC_REG 。同步暫存器屬性不是熵估計。
- AMD UG906 時序驗收： https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Verifying-Timing-Signoff 。控制/讀取的同步路徑須檢查 setup/hold；不能拿同步時序報告推論 RO 抖動品質。
- NIST SP 800-90B： https://csrc.nist.gov/pubs/sp/800/90/b/final 。正式熵源評估需要來源模型、原始資料、熵估計及健康測試。這次固定 128 次重複警報只是診斷門檻，沒有依 min-entropy 或可接受誤報率校準；也還沒有自適應比例測試，不能宣稱符合此標準。
- 官方 PYNQ v2.5 parser： https://github.com/Xilinx/PYNQ/blob/v2.5/pynq/pl_server/hwh_parser.py 。本機相容性檢查使用未修改版本，僅模擬板上容量查詢與 MMIO/Overlay 操作。

## 與老師簡報的對照

原始簡報：2026_DCS_Lab10_FPGA.pptx。第 4–16 頁建立專案與打包、第 17–20 頁加入 PS、第 26–33 頁 clock/reset/接線圖/wrapper、第 34–37 頁 bitstream 與 bit/hwh、第 39–45 頁登記/上傳/Jupyter。

本階段不使用第 21–25 頁的 DMA/AXI Stream，改為 GP0 AXI4-Lite 直接讀取本地樣本記憶體。教學補上介面大小寫、固定命名、每條線、每個設定用途及額外驗證，並保留老師原本的工具操作順序。
