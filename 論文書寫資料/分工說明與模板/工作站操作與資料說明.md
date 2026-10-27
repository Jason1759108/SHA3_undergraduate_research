# 四版本完整驗證與雙範圍掃頻操作

更新日期：2026-10-27。資料準備全部由使用者完成。以下保留從零重現的完整流程。四版已依使用者回報於 2026-10-27 19:01–19:04 開始的完整 VCS RTL 回歸全部通過，工作站現有檔案可直接進入第 4 節掃頻；不必為本次本機整理重新上傳。每版一個 RTL 指令、一個掃頻指令；每個掃頻點自動分別合成 full SHA3 與 standalone core。

## 1 採用「先 build 四個新專案，再貼入論文檔案」

唯一正式來源為 `論文書寫資料/四版本程式/`，唯一完整版為 `sha3_paper_complete.zip`。已整合 Python 2.7 與 core 載入時序修正，不再需要補丁。以下部署步驟只用於新建／重現環境，目前已通過的工作站專案不需重新部署。

1. 保留先前上傳的 `~/sha3_paper`，另外使用 `~/sha3_paper_build`，避免混入舊結果。
2. 用你在工作站原本成功的 `build` 方法建立四個全新專案。你提供的是產生後的 test，沒有 build 指令本體，所以本指南不猜它的參數或執行位置。
3. 將四個產生的專案放在 `~/sha3_paper_build/`，分別命名為下面四個名稱。名稱必須完全相同，程式會據此辨識版本。
4. 將 ZIP 解壓到本機暫存位置，透過 MobaXterm **逐版合併資料夾內容**，不要以整個目錄取代遠端目錄。00 貼入 00、01 貼入 01、02 貼入 02；同名的論文程式／測試檔選覆蓋。
5. 每版根目錄的 README.md、source_manifest.json、source_hashes.csv、prepared_hashes.csv 也貼入對應專案根目錄。共同的 check_workstation.sh、collect_results.sh 放在 `~/sha3_paper_build/`。

```text
~/sha3_paper_build/
  check_workstation.sh
  collect_results.sh
  V0_C3_NoFT/
  V1_State1600_SECDED_Replay/
  V2_Lane64_SECDED_Replay/
  V3_LaneParity_LocalReplay/
    00_TESTBED/  學校 Makefile ＋ 該版論文 TB／runner
    01_RTL/      學校工具捷徑 ＋ 該版完整 RTL／core wrapper
    02_SYN/      學校設定／捷徑 ＋ paper_syn.tcl／run_sweep.py／run_sweep.sh
    03_GATE/     保留學校產物，本次論文流程不使用
```

| 位置 | 貼入內容與保留規則 |
| --- | --- |
| 00_TESTBED | 貼入 PATTERN、TESTBED、filelist、補測、計時、runner 與 paper_compat.py；保留學校 build 產生的 Makefile。完整版附有獨立使用的 Makefile，不必覆蓋學校版本。 |
| 01_RTL | 套件全部設計檔貼入；學校 Makefile、工具捷徑及指向 00 的連結保留。示範 test.sv 不在論文 filelist 中，不會參與編譯。 |
| 02_SYN | 只新增 paper_syn.tcl、run_sweep.py、run_sweep.sh、paper_compat.py；不覆蓋學校 syn.tcl、Makefile、.synopsys_dc.setup、01_run_dc 等。 |
| 03_GATE | 不貼任何檔案、不執行；本流程沒有聲稱完成 gate-level simulation。 |

V1 的 1600 overlay 已包含在套件內，不需再套用其他補丁。四版不可混貼。不要把舊 test 的 simv、log、Report、Netlist 複製進來；那些是示範設計的結果。

**論文正式入口仍是 `00_TESTBED/run_all_rtl.sh` 與 `02_SYN/run_sweep.sh`。** 學校 `01_run_vcs_rtl` 只跑單一 Makefile 目標，不能代替完整補測。`01_run_dc` 呼叫 make syn，而原 syn.tcl 的 DESIGN=test；不能用它代替 full/core 掃頻。

## 2 工作站環境確認（先完成，才開始 RTL）

你的互動 shell 表現為 csh/tcsh。不要再貼跨行的 `bash -c '...'`；本指南直接使用 `bash 檔名.sh`，一行一行執行。

```bash
cd ~/sha3_paper_build
bash check_workstation.sh
```

這個檔案只檢查 Python、工具 PATH 與 library 可讀性，不會安裝軟體或啟動 VCS/DC。2026-10-27 已將四版 RTL／掃頻腳本改成相容 Python 2.7 與 Python 3.4 以上，使用標準函式庫及套件附帶的 paper_compat.py；不需 pip、Miniforge 或另裝 Python。工作站現有 `/usr/bin/python` 2.7.5 是本次部署目標。

若先前曾設定其他 PYTHON，請在目前 tcsh 終端機執行：

```bash
setenv PYTHON /usr/bin/python
bash check_workstation.sh
```

重新登入後 wrapper 也會優先尋找 python。這是本次改寫後才支援 Python 2，舊 ZIP 的腳本不具此相容性。請確認 00 與 02 都有新的 paper_compat.py，不能只把舊腳本 python3 字樣改成 python。

本機已用 Python 2.7.18 與 3.12.4 實際執行四版腳本流程測試：模擬工具輸出的全套測試調度、CSV／JSON、full/core 掃頻、單位／能耗公式、失敗／timing／來源異動拒絕，以及真實子程序成功／失敗／逾時。這些流程檢查不等於 VCS/DC 結果；後續使用者已回報工作站 Python 2.7.5 與四版完整 VCS 測試通過，使用者已回報 DC 修正後試跑通過，完整掃頻結果尚待回收。

### 已從你提供的 test 核對的環境

- 00_TESTBED/Makefile 使用 VCS `-full64 -sverilog`；我們的總 runner 同樣使用這兩項。runner 會逐測試指定 filelist/top，不依賴示範 test.sv。
- 02_SYN/01_run_dc 內容為 `make syn`，學校 Makefile 的 DC 執行檔是 dcnxt_shell。
- 預設 TSMC40 target：`sc9_cln40g_base_rvt_tt_typical_max_0p90v_25c.db`，路徑 `/usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/SynopsysDC/db/sc9_base_rvt/`，與論文套件原設定一致。
- 下載的 test 中 01/02 的 Makefile 等連結未完整保留下來，因此直接在 Linux build 能保留這些連結；不要把下載的 test 當成可直接還原的完整專案。
- 掃頻預設明確呼叫 `make -f ../00_TESTBED/Makefile setup_dc PROCESS=TSMC40`，在 02 重建製程 setup，並保存副本。若要用特定既有設定，四版掃頻命令都加 `--setup /同一份設定的絕對路徑/.synopsys_dc.setup`；此模式不重建 setup。
- 這些是檔案設定的核對，不代表工作站的工具授權、library 或 VCS/DC 已通過實際執行。

## 3 四版 RTL 各跑一次

依序執行下列指令。腳本會分別編譯、執行所有適用測試，不是只挑一份 PATTERN。每一項同時檢查程序回傳碼、成功標記與失敗標記。

```bash
cd ~/sha3_paper_build/V0_C3_NoFT/00_TESTBED
bash run_all_rtl.sh

cd ~/sha3_paper_build/V1_State1600_SECDED_Replay/00_TESTBED
bash run_all_rtl.sh

cd ~/sha3_paper_build/V2_Lane64_SECDED_Replay/00_TESTBED
bash run_all_rtl.sh

cd ~/sha3_paper_build/V3_LaneParity_LocalReplay/00_TESTBED
bash run_all_rtl.sh
```

每版最後必須看到：`[SUCCESS] Complete RTL suite passed!`。每項測試也會印 `[PASS] normal`、`[PASS] ft` 等。任何 `[FAIL]` 都不能忽略，即使原 PATTERN 使用 `$finish` 回傳 0，也會被總流程判為失敗。

| 版本 | 這一個指令涵蓋的測試 |
| --- | --- |
| V0 | 原正常 SHA3-256 18 案例、每筆訊息計時、standalone core 4 組完整 state 向量 |
| V1 | 正常 18 案例、原 1600 FT 12 案例、跨 lane 6 案例、原 Hamming64 單元、Hamming1600 單元、core 4 向量 |
| V2 | 正常 18 案例、原 lane SECDED FT 12 案例、跨 lane 6 案例、原 Hamming64 單元、core 4 向量 |
| V3 | 正常 18 案例、原 parity/replay 153 案例、跨 lane 6 案例、原 predictor/checker 33000 checks、core 4 向量 |

正常測試涵蓋空訊息、短訊息、135/136/137-byte padding 邊界、272/300-byte 多區塊、4096-byte 長訊息。V1/V2 原 FT 涵蓋單錯修正、同 lane 雙錯 replay、D checkpoint、第一／最後操作。V3 原 FT 包含 C/D、不同注入位置、奇數與偶數錯誤、有限連續故障及邊界訊息。兩個預期漏偵測案例「通過」代表觀察到設計盲點，不代表恢復成功。

新增跨 lane 測試：baseline 加 θ col0/col3、χ row0/row3、最後一輪 χ row4，共 6 案例。在同一拍兩個 active lanes 各翻轉一個資料 bit；驗證狀態／hold／replay、額外週期與最終 digest。V1 在大 codeword 上注入，V2 在兩個 lane codeword 上注入，V3 在 predictor 之外的 next-state 資料上注入。測試沒有透過 top 注入端提供錯誤 lane 定位資訊。

新增 Hamming1600 單元：3 種資料，每種檢查無錯、全部 1612 個單 bit 位置、相鄰雙 bit 與各 bit 配 overall parity 的雙錯；共 14508 checks。雙錯不是所有可能配對的窮舉，不把這個數字當所有故障覆蓋率。

standalone core 的 4 組輸入為全零、全一、遞增 lane、固定非均勻資料；每組比對全部 1600-bit Keccak-f 輸出，另量 core 的 start-to-done 週期。

### RTL 自動產物

每版會產生：

```text
V*/
  rtl_latest.json
  results/rtl/YYYYMMDD_HHMMSS/
    normal/compile.log、simulation.log、模擬執行檔與編譯中間檔
    ft/、cross_lane/、hamming_unit/、hamming1600_unit/、parity_unit/、core/
      僅建立該版本適用的測試目錄
    latency.csv
    case_results.csv
    rtl_summary.json
```

`latency.csv`：每筆訊息的 bytes、端到端 cycles、permutation 次數與累計 core cycles。

`case_results.csv`：測試名稱、案例、完整 PASS 訊息、可讀取的 key=value 量測欄位；原始細節仍以 `simulation.log` 為準。

`rtl_summary.json`：全套通過狀態、版本、模擬器、每項 log、4096-byte 指標、standalone core cycles、00/01 來源 SHA-256。`rtl_latest.json` 是掃頻讀取的同份摘要。只跑 `--only` 開發子集不會產生掃頻核准摘要。

本機 Verilator 已量得四版皆為 4096 bytes／31 permutations／7575 端到端 cycles，standalone core 為 241 cycles。這些是本機確認值；正式工作站流程會重新量，不以硬編碼數值代替結果。原本記憶中的 240 是 24 rounds × 10 操作拍，與 start/done 介面計數不同。

## 4 四版雙範圍掃頻各跑一次

目前正式掃頻改為 **10.0 ns 至 1.0 ns，每次減少 0.1 ns**，含兩端共 91 點。共同目錄的 run_dense_sweep.sh 自動產生完整列表，固定 TSMC40，沿用各版 run_sweep.sh。

```bash
cd ~/sha3_paper_build
bash run_dense_sweep.sh V0_C3_NoFT
bash run_dense_sweep.sh V1_State1600_SECDED_Replay
bash run_dense_sweep.sh V2_Lane64_SECDED_Replay
bash run_dense_sweep.sh V3_LaneParity_LocalReplay
```

每行等前一版完成並檢查結果後再執行。每版 91 periods × 2 scopes＝182 次 DC，四版共 728 次；保留逐點完整 reports、netlists 與來源副本，時間與磁碟需求都會增加。只查看 period 列表可用 `bash run_dense_sweep.sh --list-only`，不會啟動 DC。

`TIMING_FAIL`（slack < 0）會保留並繼續其他點，不會因第一次 timing 失敗而停止；工具或必要報告錯誤仍會停止，需修復後重跑。

操作點選擇：各 version/scope 分開，在 VALID 點中選 estimated_energy_per_bit_pj 最低者，作為本網格內最低估計 energy/bit 點；其他目標（最高吞吐、最低功耗）需分別選擇，不混稱唯一最佳。主四版公平比較仍須選共同 VALID 的相同 period。功耗維持 vectorless estimate。

時序邊界：列出最短 slack >= 0 的實測 period，以及相鄰更短的 slack < 0 點；實際可用操作點另外要求狀態為 VALID，不能忽略其他 constraint。如果整段沒有出現通過／失敗交界，就表示範圍未涵蓋邊界；若出現不單調結果，列出所有交界並復核，不假設一個全域閾值。0.1 ns 是網格解析度，不是精確極限；必要時在交界附近再以 0.01 ns 細掃。

掃頻先檢查 RTL 完整摘要及來源 SHA-256；00/01 若改動，就要求重跑 RTL。然後建立各點獨立來源副本、setup、reports 與 netlist。工具或報告錯誤採 fail-fast，保存已產生資料，不把未執行點補成 0。

### 合成條件與保護保留

- full：原 `sha3_ultra_low_power_top`；V3 固定 FT_ENABLE=1。
- core：`paper_keccak_core`。包含 state bank、round scheduler、lane gating、θ/ρπ/χ/ι 及該版 FT；排除 message buffer、padding、absorb XOR、外層 SHA3 FSM 與 formatter。1600-bit state loading 是此獨立邊界的介面，載入週期不算 permutation latency；端口 load/delay 假設要在論文說明。
- 共用 clock uncertainty 0.1 ns、I/O delay 0.5T、input transition 0.5、output load 0.05、同一 library；保存實際 units、setup、ports、SDC。遇到非 1 ns 的 library time unit，腳本停止，不偷偷把數字當 ns。
- 注入端固定為 0；reset 排除正常 timing 路徑。Hamming checking instances／parity predictors 先個別 compile 成 mapped logic，再保留邊界，避免最佳化把無錯路徑化簡掉。V1 要有 5 個 checking instances、V2 29 個、V3 2 個 predictors；V0 為 0。這是明示的保護保留政策，不宣稱沒有額外最佳化限制。
- 功耗是共用輸入 0.1 toggles/cycle、static probability 0.5 的 vectorless 估計；保留 activity.rpt，記錄已施加的輸入活動假設（依套用順序，後者覆蓋前者）；不是內部節點傳播活動報告。沒有 SAIF/VCD 活動回標，不報真實工作負載或故障期間的能量。

### 掃頻自動產物

```text
V*/results/sweep/YYYYMMDD_HHMMSS/
  request.json、rtl_summary.json、synopsys_dc.setup、setup.log
  sweep.csv、sweep_summary.json
  full_10ns/、core_10ns/、full_8ns/、core_8ns/…
    00_TESTBED/、01_RTL/、02_SYN/      該點實際使用的副本
    02_SYN/dc.log
    02_SYN/Report/
      area.rpt、power.rpt、power_hierarchy.rpt、timing.rpt
      check_design.rpt、check_timing.rpt、constraints.rpt、qor.rpt
      clocks.rpt、ports.rpt、references.rpt、design.rpt、libraries.rpt
      activity.rpt、units.rpt、protection_instances.csv、run_metadata.txt
    02_SYN/Netlist/
      *_SYN.v、*_SYN.ddc、*_SYN.sdc、*_SYN.sdf
```

不要只搬 CSV；保存整個 `results/`。setup、工具 log 與 netlist 能讓老師／AI 查出版本、library、保護保留與 timing 問題。

`sweep.csv` 一列一個 version/scope/period：面積、dynamic/leakage/total mW、worst slack、兩種 cycles、full/core 吞吐、估計 energy/bit、舊式 full-power/core-throughput 比值、狀態與原始資料路徑。

| 狀態 | 意義與處理 |
| --- | --- |
| VALID | 必要報告齊全、mapping/check_design／保護保留通過、timing 與所報 constraints 通過，可列有效操作點 |
| TIMING_FAIL | slack < 0；保留原始數據但不填有效吞吐／energy，不拿來宣稱可運作頻率 |
| CONSTRAINT_FAIL | setup slack 非負但其他所報 constraint 有 VIOLATED；不能當有效操作點 |
| ERROR | 工具、報告、單位或未約束 timing 等問題；停止後續點，查看該點 dc.log／Report |

最後必須看到 `[SUCCESS] Sweep completed; usable full/core data saved.`。至少 full 與 core 各有一個 VALID 點；論文的四版數值比較還要選四版共同 VALID 的相同 period。若沒有共同點，調寬 period 後重跑，不能混用不同頻率假裝同條件。

## 5 功耗與吞吐計算

令 T 為 ns、P 為 mW，則吞吐單位 Gbps，P/吞吐單位 pJ/bit。

| 指標 | 計算 | 論文用途 |
| --- | --- | --- |
| Full SHA3 throughput | `32768 / (C_e2e × T)` | 4096-byte 有效訊息端到端主指標 |
| Standalone core rate throughput | `1088 / (C_core × T)` | 排除外圍處理的補充指標；分母含所定義的 start/done 介面週期 |
| Full estimated energy/bit | `P_full / TP_full` | 主結果；vectorless power-normalized estimate |
| Core estimated energy/bit | `P_core / TP_core` | 獨立 core 合成結果；不是從 full 功耗猜比例 |
| Full-power core-normalized | `P_full / TP_core` | 舊方法對照欄，不能改稱完整 SHA3 實際訊息能量 |

兩種合成邊界的最佳化和介面負載不同，`P_full − P_core` 或 `A_full − A_core` 不能直接宣稱就是外圍模組的實體成本。

## 6 回傳與寫論文

```bash
cd ~/sha3_paper_build
bash collect_results.sh
```

將產生的 `paper_results_日期時間.tar.gz` 下載後解開到本機 `論文書寫資料/工作站結果/`。壓縮檔內保留 `V*/results/` 與 `rtl_latest.json`；不包含製程庫。不要刪除工作站上的這批結果直到本機確認收齊。

後續兩人依各自手冊完成段落與圖表，使用此次工作站結果。研究主張限定為：指定模型下的 RTL 功能／故障行為、同環境的合成成本、無錯吞吐與 vectorless 功耗估計。此流程不證明任意實體故障、全 state 儲存保護、post-layout timing、活動式恢復能量或普遍 100% fault coverage。

## 7 本機已檢查與仍需工作站執行的範圍

四版的完整適用 RTL suite 已在本機 Verilator 實際通過；詳細 log 保留於 `參考資料/本機流程檢查/`。V0/V1/V2 的 RHO_OFFSET／PI_Y_MAP 改用與 V3 相同的 packed 常數表宣告，索引和值不變，以便本機 elaboration；原專案 `src` 未改。

本機沒有 VCS／Design Compiler／製程庫。四版 VCS 通過依據為使用者提供的工作站成功輸出；完整原始 log 與 rtl_latest.json 尚待下載存檔。使用者已回報 DC 修正後試跑通過；原始試跑報告與完整密集掃頻結果尚待回收。合成腳本、報告解析、狀態判斷與打包流程會先做可執行的本機檢查，但工作站首次執行仍可能遇到工具版本或 library 設定差異。若有 ERROR，保留完整 log 交回處理；不要自行刪除檢查或把失敗標成通過。

## 8 已整合修正與版本基準

完整版已包含 LF 換行、Python 2.7 相容 runner／paper_compat.py，以及 core testbench 的無競爭載入時序與 1600-bit 載入檢查。舊補丁與舊完整版 ZIP 已整併，不應再重複套用。

| 版本 | 使用者回報成功的工作站 RTL run |
| --- | --- |
| V0_C3_NoFT | 20261027_190128 |
| V1_State1600_SECDED_Replay | 20261027_190140 |
| V2_Lane64_SECDED_Replay | 20261027_190257 |
| V3_LaneParity_LocalReplay | 20261027_190452 |

四版均顯示 Complete RTL suite passed。可將此版作為本輪論文 RTL 比較基準。此結果確認已實作測試涵蓋的正常功能、指定故障／修復行為及獨立 core 向量；不是全故障窮舉，也不保證未涵蓋的永久故障、任意多 bit 故障或實體／合成後故障行為。V3 預期漏偵測案例通過是驗證盲點存在，不是宣稱修復。

workstation_rtl_validation.json 記錄使用者回報證據，不是 sweep 使用的 rtl_latest.json。正式來源對應與週期數仍以工作站 rtl_latest.json、simulation.log 與實際來源指紋為準；目前不製造本機的 rtl_latest.json，也不把 mock 測試混入正式結果。

現有工作站 00/01 不需更動，保留 results/ 與 rtl_latest.json，接著執行第 4 節。將來若改動 RTL/TB/runner，需重跑完整 RTL 才能讓來源指紋對得上。新建環境仍先 build，再按第 1 節合併完整版檔案；不要直接覆蓋已完成實驗的來源。

## 9 工作站 DC 報告指令相容修正

工作站回報 check_timing 不支援 -verbose、report_switching_activity 不存在。四版 Tcl 已改用 check_timing，並在成功施加 set_switching_activity 後記錄 port、static probability、toggle rate、base clock 到 activity.rpt。它只記錄顯式輸入假設，非波形量測或內部活動傳播；沒有更改功耗模型或略過 timing／DC 錯誤檢查。

只更動 02_SYN/paper_syn.tcl，00/01 未改，不需重跑 RTL。舊 sweep 的逐點副本保留原腳本，不會因更新來源而被修補；需開新 sweep。先驗證 V0 的 full/core 10 ns：在其 02_SYN 執行 bash run_sweep.sh --periods 10 --process TSMC40。舊背景工作結束後，再啟動新的完整掃頻，使用不同 log 檔名保留舊錯誤紀錄。

## 10 DC 時間單位格式修正與逐檔說明

DC R-2020.09 的 units.rpt 寫作 Time_unit : 1.0e-09 Second(ns)，等於 1 ns。run_sweep.py 已支援此格式及等價時間單位寫法，仍拒絕真正非 1 ns／缺失／未知格式，並保留功耗各值獨立單位換算。只更新 02_SYN/run_sweep.py，不需重跑 RTL。先驗證 V0 10 ns full/core，再啟動密集掃頻；使用者後續已回報修正後試跑通過；完整四版密集掃頻仍須以正式回收結果確認。

完整的逐檔用途、新舊 sweep 差異、00/01/02 呼叫關係、每一份報告及 netlist 用途，請讀「論文_RTL與合成工具架構說明.md」（完整版中名稱為 ARCHITECTURE_GUIDE.md）。

Git 分享：四版本程式保留原始檔案位元組，shell 固定 LF；不要為了整理換行而覆蓋正在工作站執行的來源。新環境仍自行跑完整 RTL 產生當地 rtl_latest.json。
