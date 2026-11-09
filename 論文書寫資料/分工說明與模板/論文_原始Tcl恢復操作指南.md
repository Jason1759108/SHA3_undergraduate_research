# V1/V2/V3 原始 Tcl 重現（2026-10-28）

> **歷史除錯指南。** 不作固定 10 ns 論文路線的操作指令；現行資料見 [工作站操作與資料說明](./工作站操作與資料說明.md)。

本文件優先於先前共同 Tcl 的說明。未拆成八個專案。

## 改動範圍

- V1：commit 0798e0b9ed8ba1b73a2cdd427b2441c755fb4903 的 syn_1600.tcl。
- V2：同 commit 的 syn.tcl。
- V3：commit a352ebfff67c7ee28e5366ab4ce443beecac44e4 的 syn.tcl。
- 原始檔案從 Git 直接取回，逐位元組相符，含原註解。
- legacy_sweep_body.tcl 與對應原始檔的唯一差異：最後 exit 前新增 source paper_legacy_reports.tcl。
- paper_syn.tcl 只建立 Report/Netlist 及選擇 full/core 入口。full 不再套用共同版新增的保護單元凍結、reset false path、所有 ft_* 固定等處理；各版舊有設定保持原樣。
- paper_legacy_reports.tcl 只輸出額外報告、完成標記並複製原 netlist/SDF/SDC/DDC 為腳本使用的名稱；不再合成或產生第二份不同設定的 SDF。
- V3 的 FT_ENABLE 在掃頻程序明確選為 1（原檔預設也是 1），避免外部環境意外選成無保護版本。
- V3 原本已有兩個 predictor 的預先合成及保留設定，繼續保留。
- V0 full 維持此前已重現的 C3 流程。
- 00/01、原先 RTL 成功記錄、default make vcs_gate 無 SDF 回標模式不改。

## 歷史重現限制

這次只恢復 Tcl，沒有把 V1/V2 sha3_pkg.sv 的 packed 常數宣告改回原宣告。V0 也採相同相容性修改而曾成功對上，但不能由此保證其他版相同。工具、library、來源與歷史紀錄是否確實對應仍由工作站結果判斷。HISTORY_DIFFERENT 會保留差異，不調參數湊數字。

## 執行

先等目前工作結束，再上傳新版完整 ZIP。以下不改舊 results 或 00/01：

```text
cd ~/sha3_paper_build
unzip -o sha3_paper_complete.zip 'V*/02_SYN/*' 'V*/prepared_hashes.csv' run_four_sweeps.sh run_dense_sweep.sh LEGACY_RESTORE_GUIDE.md GATE_SWEEP_GUIDE.md
nohup bash run_four_sweeps.sh check < /dev/null >& check_legacy_full.log &
```

本輪只跑四版完整 SHA3 的 10 ns，每版一次合成＋一次 default gate，共四次合成及四次 gate。檢查：

```text
cat check_legacy_full.log
set logdir = `cat latest_sweep_logs.txt`
tail -n 30 "$logdir"/*.log
```

先看 HISTORY_MATCH/DIFFERENT，再看 SYN_OK 與 GATE_PASS。三者意義不同。工作站尚未執行本次修訂，不能提前宣稱重現。

確認後 `nohup bash run_four_sweeps.sh dense < /dev/null >& dense_launcher.log &` 只跑 full，10.0 到 1.0 ns、間隔 0.1 ns，每版 91 點。

原實驗 core 流程另保留於 V1/V2/V3 的 paper_core_syn.tcl；不在上述入口執行，也未修正其既有介面時序問題。直接使用 run_sweep.sh 時請明確加 --scopes full，避免沿用其 full/core 預設。這次不聲稱 core 已恢復成歷史流程。
