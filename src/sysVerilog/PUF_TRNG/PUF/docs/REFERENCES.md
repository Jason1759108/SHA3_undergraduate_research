# 參考資料

以下外部資料提供方法或工具背景，不代表本文實驗結果由文獻推導。本站測試結論請引用VALIDATION與原始證據。整理查閱日期：2026-11-17。

## RO-PUF方法

- *A Novel Technique for Ring Oscillator Based PUFs to Enroll Stable Challenge Response Pairs*，2014，[DOI:10.1109/CIT.2014.145](https://doi.org/10.1109/CIT.2014.145)。背景：註冊時篩除不穩定回應。
- *Oscillator Selection Strategies to Optimize a Physically Unclonable Function for IoT Systems Security*，[作者研究原文](https://pmc.ncbi.nlm.nih.gov/articles/PMC10181650/)。背景：配對策略、重現性、唯一性與環境影響；不是本設計效能的證據。

## 工具官方文件

- [Verilator tracing controls](https://verilator.org/guide/latest/control.html)：波形追蹤控制。
- [AMD UG903 Using Constraints](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Path-Segmentation)：max-delay/datapath-only等時序約束背景；實際腳本以repo為準。
- [AMD UG835 set_bus_skew](https://docs.amd.com/r/2021.2-English/ug835-vivado-tcl-commands/set_bus_skew)：Gray CDC bus-skew約束背景。
- [PYNQ Overlay](https://pynq.readthedocs.io/en/v3.1/pynq_libraries/overlay.html)：bit/HWH、Overlay類別。文件為v3.1，歷史板端實測版本為2.5，須注意版本差異。

本目錄沒有收錄論文全文、學校私有標準元件library或商用工具手冊；依學校授權取得。
