# 保留工作站原本 01_run_vcs_gate 的手動診斷流程（歷史資料）

目前正式的 10 ns 流程見 `README_10NS_GATE.md`。本文件記錄早期手動診斷方法，未用於 2026-11-04 四版結果。

這兩個檔案適用於 parity 的 FT_ENABLE=1（合成輸出 SHA3_parity_SYN.v）。目前 `src/sysVerilog/01_RTL` 已套用 CE1 的狀態暫存器 clock-enable 修改；若要重現歷史原版數字，應使用論文資料中的原版 V3，不可混用。`filelist_gate_manual.f` 列 PATTERN、03 自己的 TESTBED 和 02 的合成 netlist；`TESTBED_gate_manual.sv` 實例化合成頂層並將注錯輸入綁零。

工作站 build 可能讓 `03_GATE/filelist.f` 與 `TESTBED.sv` 成為指向 00_TESTBED 的符號連結。不要直接編輯連結。將兩個 `_manual` 檔上傳到工作站 `~/SHA3/03_GATE/`，再於該目錄逐行執行：

```text
ls -l filelist.f TESTBED.sv
cp --remove-destination filelist_gate_manual.f filelist.f
cp --remove-destination TESTBED_gate_manual.sv TESTBED.sv
ls -l filelist.f TESTBED.sv
cat filelist.f
./01_run_vcs_gate
```

`cp --remove-destination` 會先移除 03 的目的檔或連結，再建立 03 的獨立檔案；不會改到 00。第二次 `ls -l` 應顯示普通檔案，不應再有 `-> ../00_TESTBED/...`。

先在 `~/SHA3/02_SYN` 用原 `./01_run_dc` 產生同一版的 `Netlist/SHA3_parity_SYN.v`。01 RTL 應使用這次修改後的三個 CE1 檔案及同一份 parity 其餘 RTL；02 Tcl 保留原 parity 設定，工作站 build 的 Makefile、`.synopsys_dc.setup` 也保留。03 的原 `01_run_vcs_gate` 與 Makefile 不需修改。執行時看到 `Parsing design file '../02_SYN/Netlist/SHA3_parity_SYN.v'` 才表示真正讀到了 gate netlist。

這個手動版沒有載入 SDF，但原 Makefile 仍載入製程元件模型與 timing check。即使 CE1 在帶 SDF 測試中正常功能通過，這種不帶 SDF 模式仍可能報時序違反，不能據此認定 CE1 失敗。若要確認 CE1 修正效果，請以論文資料中的 CE1 帶 SDF gate 測試為準。原 `01_run_vcs_gate` 只有 `make vcs_gate define="$*"`，PATTERN 印出 `[FAIL]` 時 VCS 也可能回傳 0；請看完整輸出與 `[SUCCESS] All 18 SHA3-256 test cases passed!` 是否出現。

若要在這個獨立工作站專案中用**同一次 02 合成輸出的 netlist 與 SDF**對照 CE1，另外上傳 `TESTBED_gate_sdf_manual.sv` 到 `~/SHA3/03_GATE/`。確認 `../02_SYN/Netlist/SHA3_parity_SYN.v` 和 `.sdf` 都存在後，在 03 目錄執行：

```text
cp --remove-destination filelist_gate_manual.f filelist.f
cp --remove-destination TESTBED_gate_sdf_manual.sv TESTBED.sv
./01_run_vcs_gate
grep -E 'SDF annotation completed|Total errors:|Total warnings:' sdf_annotation.log
grep -E '\[SUCCESS\]|\[FAIL\]|Timing violation' vcs.log | tail -n 30
```

`filelist.f` 維持同一份 netlist 清單；只換 03 的 TESTBED，並保留原本的 `01_run_vcs_gate`、Makefile、製程元件模型及 timing check。輸出 `sdf_annotation.log` 需有 `SDF annotation completed` 和 `Total errors: 0`；再看 18 筆測試的 `[SUCCESS]` 與有無 `Timing violation`。已知 `SDFCOM_CFTC` 警告表示部分 SDF timing check 未能對應到元件模型，因此即使功能全過，也不能宣稱完整時序簽核。若要重跑原先不載 SDF 的實驗，將 `TESTBED_gate_manual.sv` 複製回 03 的 `TESTBED.sv` 即可。

## 警告診斷（不改測試設定）

另可上傳 `diagnose_gate_warnings.py` 到同一個工作站 `03_GATE` 目錄，執行 `python diagnose_gate_warnings.py`。它只讀取本機的 `sdf_annotation.log` 和 `vcs.log`，印出 SDF 警告代碼、找不到對應的 timing check 類型、`TFIPC` 數量、功能與 timing violation 結果；不印元件名稱、實例名稱或製程路徑，也不修改 RTL、netlist、SDF、Makefile 或 Tcl。若總數不吻合，先檢查該次執行的 log 是否完整，不能把未知警告當成已知警告。

目前這次 V3 記錄中的 `TFIPC` 發生在合成 netlist 的元件接腳，包含只使用半加器其中一個輸出，以及某個子模組的未使用輸出；它是連線數量提示，並非 SDF 警告。`SDFCOM_CFTC` 的例子則是 SDF 有 `$hold` 檢查，VCS 使用的製程 Verilog 模型找不到可完全對應的檢查。若要消除後者且保留檢查覆蓋，必須在工作站本機核對 `.db` 與 Verilog 模型是否為相容版本，或由製程庫管理者提供配對的模型。單純關閉或隱藏警告不會補上未對應的檢查。

可選擇上傳 `probe_sdf_model.py`，在工作站 `~/SHA3/03_GATE/` 執行 `python probe_sdf_model.py sdf_annotation.log /usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/Verilog/sc9_cln40g_base_rvt_neg.v`。它只在工作站讀取該模型，不複製模型，也不輸出元件名稱或內容。輸出會將找不到的 `$hold` 第二個事件分為 reset/set、資料或其他接腳，並統計被警告的元件模型是否含 `$hold`、`$setuphold` 等語法。這是成因診斷，不是修正或完整等價證明。若幾乎全部落在 reset/set 接腳，而模型缺相應語法，就可帶這份純統計結果向製程庫管理者確認 SDF 與 Verilog 模型的配對；不要自行修改受授權限制的模型。

更新版 `probe_sdf_model.py` 另外統計 `module_has_setuphold_async_event` 和 `module_has_recrem_async_event`。前者是評估「只改 SDF 輸出為合併 SETUPHOLD」是否可能對應到模型的必要線索：若為零，合併格式通常無法替缺少的 reset/set `$hold` 找到對應檢查；若不為零，仍須以獨立 SDF 實驗驗證，不能直接修改正式 Tcl。後者檢查模型是否對 reset/set 事件另用 recovery/removal 表示。這兩項只掃描語法，不能證明條件式完全相同。

## 只改 SDF 格式的獨立實驗

目前 V3 的 6 種模型都有 reset/set 的 `$recrem`，僅 3 種有 reset/set 的 `$setuphold`，因此合併格式不保證能修好全部 4746 筆。為了量測影響，另準備 `../02_SYN/sdf_format_probe.tcl` 與 `TESTBED_gate_sdf_probe.sv`。前者從原來的 10 ns `SHA3_parity_SYN.ddc` 讀取已合成設計，**不重新 compile，也不覆蓋正式 netlist/SDF**，只輸出 `Netlist/SHA3_parity_SYN_format_probe.sdf`；後者只載入這份替代 SDF。若 DC 版本不支援 `-include`，Tcl 應報錯停止，不要改正式流程。

先上傳這兩個新檔案到工作站相應的 `02_SYN`、`03_GATE` 目錄，並確認原 10 ns 02 合成和原 SDF 03 測試已完成。工作站逐行執行：

```text
cd ~/SHA3/02_SYN
ls -l SHA3_parity_SYN.ddc Netlist/SHA3_parity_SYN.v Netlist/SHA3_parity_SYN.sdf
dcnxt_shell -f sdf_format_probe.tcl -output_log_file sdf_format_probe.log
grep SDF_FORMAT_PROBE_WRITTEN sdf_format_probe.log
ls -l Netlist/SHA3_parity_SYN_format_probe.sdf
cd ~/SHA3/03_GATE
cp vcs.log vcs_before_sdf_probe.log
cp sdf_annotation.log sdf_annotation_before_sdf_probe.log
cp --remove-destination TESTBED_gate_sdf_probe.sv TESTBED.sv
./01_run_vcs_gate
python diagnose_gate_warnings.py
```

若替代 SDF 的警告比原來 4746 筆少，仍需確認 `SDF reported errors: 0`、18 筆全過、`VCS timing violations: 0`，以及少掉的檢查確實被模型中的對應項涵蓋，不能只按警告數下降就認定修好。實驗後要恢復正式 03 測試入口，執行 `cp --remove-destination TESTBED_gate_sdf_manual.sv TESTBED.sv`。原 SDF 和 netlist 都沒有被此實驗覆蓋；正式掃頻仍應使用既定流程。
