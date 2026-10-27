# 論文四版本：RTL 驗證、合成掃頻與檔案架構說明

更新：2026-10-27。依目前實際程式、原 src/sysVerilog/my_sweep.sh、sweep_dc.sh、syn.tcl，以及使用者下載的學校 test 範本整理。這是工具／檔案說明，不是新的工作分工。

## 1 目前做到哪裡

四版完整工作站 VCS RTL 測試已由使用者回報 PASS。已通過正常 SHA3、各版適用的 FT／單元／跨 lane 測試與 standalone core 測試；驗證的是指定案例，不是所有可能故障的窮舉。V3 的預期漏偵測案例是確認盲點，不是修復成功。

使用者已回報 DC 相容修正後試跑通過，尚未回收四版完整密集掃頻結果。V0 第一次 10 ns 曾取得正 slack，但報告指令出錯，不能把那個點當正式有效結果。第二次遭時間單位解析器拒絕：實際報告是 `Time_unit : 1.0e-09 Second(ns)`，確實等於 1 ns，已修正解析方式。不得把目前腳本輸出錯誤當成硬體 timing 極限。

工作站 VCS 為 L-2016.06-SP1-1，units.rpt 顯示 DC 為 R-2020.09；兩者版本不同，不能用 VCS 版本推論 DC 支援哪些指令。

## 2 四種程式各做什麼

| 檔案類型 | 執行者 | 工作 |
| --- | --- | --- |
| .sv | VCS 模擬；設計 RTL 也由 DC 讀取 | 硬體設計、刺激、故障注入、參考答案與計時。TB 不合成。 |
| .sh | Bash | 找 Python、產生週期列表、呼叫總流程、打包資料；本身不合成硬體。 |
| .py | 工作站 Python 2.7，亦相容 Python 3 | 調度各測試／合成點、保存資料、檢查結果、計算 CSV／JSON。無第三方套件需求。 |
| .tcl | Synopsys DC | 讀 RTL、選 top、設定約束與活動假設、compile、輸出報告和 netlist。 |
| Makefile | make | 學校整套工具命令的集合；本次正式掃頻主要用其中的 setup_dc 產生製程設定。 |

增加 Python 是實作選擇，不是 VCS/DC 要求。原本 Bash+awk 也能完成相同功能，但新流程需要跨測試整合、JSON、檔案指紋、單位判讀、雙範圍結果及錯誤狀態，因此集中在 Python。最初我不應假設工作站有 Python 3；現在已提供 Python 2.7 相容層。

## 3 實際呼叫順序

```text
RTL：
00_TESTBED/run_all_rtl.sh
  → run_all_rtl.py + paper_compat.py
  → 對該版每項測試各呼叫 vcs 編譯，再執行 simv
  → 每項 compile.log／simulation.log
  → case_results.csv、latency.csv、rtl_summary.json
  → 全套通過才寫版本根目錄 rtl_latest.json

掃頻：
共同目錄 run_dense_sweep.sh VERSION
  → 該版 02_SYN/run_sweep.sh
  → run_sweep.py + paper_compat.py
  → 讀 rtl_latest.json、比對 00/01 來源指紋
  → make -f ../00_TESTBED/Makefile setup_dc PROCESS=TSMC40
  → 每個 period 分別建立 full 與 core 的獨立資料夾
  → 各點呼叫 dcnxt_shell -f paper_syn.tcl
  → 解析報告、輸出 sweep.csv／sweep_summary.json

資料回收：
共同目錄 collect_results.sh
  → 收四版 results/ 和 rtl_latest.json → paper_results_時間.tar.gz
```

`nohup ... &` 只是把最外層腳本留在背景執行；不會改變合成方法。四版平行＝四個工作，每版內 full/core 與各 period 仍依序。不是同時跑 728 個 DC。

## 4 共同 paper 目錄與版本根目錄

本機正式來源：`論文書寫資料/四版本程式/`；工作站共同目錄：`~/sha3_paper_build/`。兩者不是同步磁碟，改本機檔案仍需上傳，工作站結果也需下載。

| 共同檔案 | 用途／是否執行 |
| --- | --- |
| README.md | 完整包使用說明，不執行。 |
| WORKSTATION_GUIDE.md | 逐行操作、輸出位置、狀態及計算口徑；對應本機工作站操作與資料說明.md。 |
| ARCHITECTURE_GUIDE.md | 本文件的隨包副本。 |
| check_workstation.sh | 只查 Python、VCS、DC、make、tar 與 TSMC40 library 可讀性；不代表授權或合成已成功。 |
| run_dense_sweep.sh | 整數十分之一生成 10.0→1.0 ns、步長 0.1、共 91 點；選一版後交給 run_sweep.sh。--list-only 只列數字。 |
| collect_results.sh | 收所有四版 results/ 與 rtl_latest.json。會包含失敗紀錄；打包成功不等於四版掃頻全部成功。 |
| versions.json | 四版來源 commit、版本名稱、入口、修正／驗證狀態索引；不是合成引擎。 |
| workstation_rtl_validation.json | 使用者回報的四次完整 PASS 紀錄；不是掃頻核准用的 rtl_latest.json。 |
| sweep_logs/V0.log～V3.log | 使用 nohup 時 shell 產生的外層進度 log，不是 DC 詳細 log。 |
| sha3_paper_complete.zip | 唯一完整來源包，不包含工作站正式結果與製程 library。 |
| paper_results_時間.tar.gz | collect_results.sh 產生的結果包；與完整來源 ZIP 用途不同。 |

如果你依修復指示，曾把單一 paper_syn.tcl 或 run_sweep.py 上傳在共同目錄，它只是複製到四版用的中轉檔，正式執行入口不讀共同目錄這份。不要只改中轉檔而忘記複製到各版 02_SYN。

每版根目錄：

| 檔案／目錄 | 用途 |
| --- | --- |
| README.md | 該版本來源、入口與驗證狀態。 |
| source_manifest.json | 原始版本與 overlay 來源記錄。 |
| source_hashes.csv | 原始匯出來源的 hash；不等於修正後程式。 |
| prepared_hashes.csv | 本機完整版目前各檔案 SHA-256 索引；不是工作站執行核准。 |
| rtl_latest.json | 完整 RTL runner 在工作站產生，記錄 PASS、cycles、測試 log、實際 00/01 hash；02 真正會讀這份。 |
| results/ | 正式執行產物，不是設計來源；每次新時間戳，舊失敗結果保留。 |

學校 build 合併後會多出捷徑、symlink、示範 test.sv；本機原始碼包沒有全部複製這些，是因為它們由學校 build 提供，不是漏掉論文模組。正式來源比對以當次工作站 rtl_latest.json 為準。

## 5 00_TESTBED 每個檔案

| 檔案 | 來源／用途／正式流程如何使用 |
| --- | --- |
| Makefile | 原有工具配方；學校 build 版本保留。本機完整包另附專案版。一般 vcs_rtl 目標只跑一個所選 PATTERN，不等於新總回歸。02 會明確用它的 setup_dc。 |
| filelist.f | 原有設計與 TB 編譯清單。runner 讀取後轉成絕對路徑，依測試加入 monitor 或改用其他 top。 |
| TESTBED.sv | 原有接線頂層，實例化完整 SHA3 與 PATTERN；透過 FT_PATTERN／FT_PATTERN_1600 選擇故障測試。NO_DUMP 由 runner 設定以避免總回歸輸出大量波形。 |
| PATTERN.sv | 原正常 SHA3 刺激與黃金 digest 比對；目前各版 normal 18 案例，涵蓋空、短、padding 邊界、多 block、4096 bytes。 |
| PATTERN_FT.sv | 保留原故障刺激；V2 用 lane SECDED 版本、V3 用 parity/replay 版本。V1 正式故障回歸選另一個 1600 檔案。 |
| PATTERN_FT_1600.sv | 原 1600 故障測試；總 runner 只在 V1 選用。V2/V3 目錄仍有歷史檔案，不代表也拿來驗證該版。 |
| tb_hamming64.sv | 原 Hamming64 單元測試；V1/V2 正式執行。V3 保留歷史檔，但 parity 總流程不執行它。 |
| tb_parity_predictor.sv | 原 parity predictor/checker 單元測試；V3 正式執行，33000 checks。 |
| TESTBED_CROSS_LANE.sv | 新增 V1/V2/V3 跨 lane 測試，baseline＋五種同拍兩 lane 各翻一 bit 案例，檢查結果與恢復行為。 |
| filelist_cross_lane.f | 新增跨 lane 測試的獨立編譯清單。總 runner 目前直接由正常 filelist 抽 RTL，再加跨 lane TB；不是另讀這份清單。可作單獨操作參考。 |
| tb_hamming1600.sv | 新增 V1 1600 編碼／解碼單元測試，14508 checks；不是全部雙 bit 組合窮舉。 |
| paper_cycle_monitor.sv | 新增，以 bind 掛到正常 TESTBED，量第一個輸入 handshake 到第八個 32-bit 輸出被同步接收的 cycles、訊息 bytes、permutation 次數與 core 累計 cycles。只量測、不產生刺激、不合成。 |
| TESTBED_CORE.sv | 新增獨立 core 四向量測試，全 1600-bit 輸出比對，量 start-to-done cycles。修正 load_state 與 clock-gating 下降緣競爭；開始運算前新增完整輸入載入比對。 |
| run_all_rtl.sh | 新入口，切至自己的 00 目錄、找 Python 或使用 PYTHON 指定路徑，再執行 .py。 |
| run_all_rtl.py | 新總回歸控制器，依版本選測試，呼叫 VCS／simv，檢查回傳碼與成功／失敗訊息，抽取案例與 cycles，保存摘要與 hash。--only 是開發子集，不能產生新的完整核准摘要。 |
| paper_compat.py | 新標準函式庫相容層：Path、子程序等待／逾時、CSV UTF-8、輸出刷新等，讓同一 runner 支援 Python 2.7／3；沒有改動硬體演算法。 |

正式測試組合：V0 normal+core；V1 normal+ft+cross_lane+hamming_unit+hamming1600_unit+core；V2 normal+ft+cross_lane+hamming_unit+core；V3 normal+ft+cross_lane+parity_unit+core。

原 TB／PATTERN 的主體被保留；新增的是補測、獨立 core 驗證與總流程。檔案存在不等於被當次 runner 執行，以上選擇邏輯才是依據。

## 6 01_RTL 每個設計檔與改動界線

| 檔案 | 角色 |
| --- | --- |
| sha3_pkg.sv | 共享 state 型別、參數、輪常數／索引常數。V0/V1/V2 為本機工具相容性改用 packed RHO_OFFSET／PI_Y_MAP，值與索引不變。 |
| sha3_ultra_low_power_top.sv | 完整 SHA3 頂層：訊息處理、控制、Keccak、輸出與適用 FT 整合；full 合成 top。 |
| sha3_ctrl_fsm.sv | 完整 SHA3 的外層控制與處理階段切換。 |
| sha3_pad_domain.sv | padding／domain separation。 |
| sha3_absorb_xor.sv | 將輸入 rate block XOR 進 state。 |
| sha3_output_formatter.sv | 將結果整理為外部輸出介面。 |
| keccak_round_scheduler.sv | 排程 24 rounds、θ／χ 與 done；FT 版本配合恢復控制。 |
| keccak_theta_serial.sv | θ 序列運算及相應控制。 |
| keccak_rho_pi_wire.sv | ρ rotation 與 π lane 重排。 |
| keccak_chi_row.sv | χ row 運算。 |
| keccak_iota.sv | ι round-constant 操作。 |
| keccak_state_bank.sv | 25 個 lane 的 state 暫存器。 |
| sha3_low_power_gating.sv | lane clock gating；下降緣取樣 gate enable，故 core TB 必須給足載入取樣／寫入時間。 |
| keccak_ft_region.sv | V1/V2 的故障容錯／replay 協調邏輯。 |
| keccak_hamming64.sv | V1/V2 Hamming 邏輯所在檔。V1 已套用 1600 overlay，不能只憑檔名含 64 判定該版保護粒度。 |
| keccak_lane_ecc.sv | V1/V2 的 state／lane ECC 包裝與檢查整合；V1 使用已套用的 1600 版本。 |
| keccak_lane_parity.sv | V3 lane parity 檢查相關邏輯。 |
| keccak_parity_predictor.sv | V3 θ／χ parity prediction 模組。 |
| paper_keccak_core.sv | 唯一新增的論文用合成邊界：從各版 top 擷取 state bank、round scheduler、lane gating、Keccak 與 FT，提供 1600-bit load_state 和輸出。不是四版共用同一個保護實作。 |

core 不含 message buffer、padding、absorb XOR、外層 SHA3 FSM、輸出 formatter；load-state 載入時間不算 permutation latency。新 wrapper 是為了真正單獨合成 core 功耗／面積，不能從 full 功耗按比例猜。

原 src/、others/、references/ 未因論文副本整理而被改寫。V1 overlay 是版本建立時已整合；Python 2 修正、core TB 載入修正與近期 DC 報告修正都沒有再改寫四版保護演算法。

## 7 學校 build 在 01_RTL 原本就有的檔案

| 檔案 | 用途／本次是否當正式入口 |
| --- | --- |
| 01_run_vcs_rtl | make vcs_rtl define=...；原本單次 VCS 測試入口。論文全套用 00 的 run_all_rtl.sh。 |
| 02_irun_rtl | make irun_rtl；Cadence irun 入口，本次不用。 |
| 03_xrun_rtl | make xrun_rtl；Cadence xrun 入口，本次不用。 |
| 04_verdi | make verdi_rtl；查看設計／波形。 |
| 05_nWave | make nWave；查看波形。 |
| 08_check_design | 先清理再跑原單次 VCS，從 vcs.log 找 FAIL／Congratulations 與 latency；不是新回歸判定器。 |
| 09_clean_up | make clean；清理工具產物，不是測試步驟。 |
| Makefile、PATTERN.sv、TESTBED.sv、filelist.f | build 可能以連結共用 00 的內容；下載 test 時部分連結未保留，需以實際 Linux build 為準，不能把兩份同名檔理解成兩種設計。 |
| test.sv | 學校示範設計；論文的明確 filelist 不會編譯它。 |
| simv、simv.daidir/、csrc/ | VCS 產生的執行檔／編譯資料，不是要手動補上的原始碼。 |
| vcs.log、ucli.key、波形與 GUI 記錄 | 原流程執行產物。新 runner 把每項測試產物放進 results/rtl/，避免共用一份 vcs.log。 |

## 8 02_SYN 每個輸入／控制檔案

| 檔案 | 來源與用途 |
| --- | --- |
| .synopsys_dc.setup | 學校製程設定：search_path、target/link/synthetic library 等。預設 runner 用 00 Makefile setup_dc 依 TSMC40 重建；--setup 可指定既有檔並保留副本。不含 library 本體。 |
| Makefile | 學校配方／連結；原 01_run_dc 經 make syn 執行 DC。新 runner 直接呼叫 DC，但 setup_dc 仍沿用 00 Makefile。 |
| 01_run_dc | 原有 `make syn` 捷徑；不是新掃頻入口。 |
| 02_run_dv | 原有 `make syn_gui`，開 Design Vision 合成 GUI。 |
| 03_check_rtl | 原有 `make check_rtl`，讀 Makefile 指定設計並開 GUI；不等於新四版完整檢查。 |
| 04_view_netlist | 原有 `make view_netlist`，讀指定 DDC 開 GUI。 |
| 08_check | 原有示範檢查器；你提供的檔案硬編碼 Design=test，查 syn.log、Report/test.*、latch／mismatch／timing，不能直接拿來判論文結果。 |
| 09_clean_up | make clean，清工具產物。 |
| syn.tcl | 必須區分兩份：學校 build 保留的原檔 DESIGN=test；本機完整包的同名檔已改為相容轉接入口，設定預設版本／full／10ns 後 source paper_syn.tcl。兩者都不是正式掃頻的必經入口。 |
| syn_1600.tcl | 部分版本保留舊檔名；本機目前也是相容轉接入口。檔名不會把 V2/V3 自動變成 1600 設計；實際設計取決於版本內 RTL。 |
| paper_syn.tcl | 新正式 DC 腳本：從環境讀 version/scope/period，分析 RTL、選 full/core top、設定約束、compile、保留保護模組、輸出報告與 netlist。四版共用相同腳本，依版本分支。 |
| run_sweep.sh | 新啟動器，切到自己的 02 目錄、找 Python，再執行 run_sweep.py。 |
| run_sweep.py | 新掃頻管理器，驗證 RTL 摘要與來源、建立各點副本、執行 DC、解析報告、計算指標、記錄狀態。 |
| paper_compat.py | 同 00 的 Python 2.7 相容模組，放在 02 是讓這個目錄能獨立執行／被逐點複製。不是第二套算法。 |
| test.sv | 學校示範用設計或連結，正式 paper_syn.tcl 不分析它。 |
| syn.log、command.log、default.svf | DC 既有產物：執行 log、命令紀錄、形式驗證引導資訊。SVF 存在不代表已做形式等價驗證。 |
| Report/、Netlist/ | 報告／網表目錄；新流程有效資料放在各個 results/sweep/.../full_* 或 core_* 的 02_SYN 內，不能誤讀頂層舊 test 報告。 |

正式掃頻的環境變數：CLK_PERIOD 指定週期；PAPER_SCOPE=full/core；PAPER_VERSION 指定四版名稱。V3 elaboration 固定 FT_ENABLE=1；V0 是原始無保護設計，並非拿 V3 隨意關掉 FT 當 V0。

## 9 與原 my_sweep.sh／sweep_dc.sh 的差別

我實際找到兩支原腳本，不能把它們混成同一版。

| 項目 | my_sweep.sh | sweep_dc.sh | 現在 run_sweep.py＋paper_syn.tcl |
| --- | --- | --- | --- |
| 週期 | 檔內 seq 100→1，步長 1 | 輸入起訖／步長；支援方向 | --periods 列表；dense 入口固定 10→1、步長 0.1 |
| cycles | 硬編碼 240 | 使用者輸入 cycles/block | 從完整 RTL 摘要取端到端與 standalone core 實測值 |
| 每個點合成範圍 | 當前 syn.tcl 的一個設計 | 同左 | full 與 standalone core 各合成一次 |
| DC 啟動 | ./01_run_dc → make → syn.tcl | 可設定 RUN_SCRIPT，預設同左 | 直接 dcnxt_shell -f paper_syn.tcl；setup 仍由 Makefile 產生 |
| 是否依賴 RTL 全套通過 | 沒有強制核對 | 沒有強制核對 | 檢查 rtl_latest.json PASS、版本與 00/01 hash |
| 每點隔離 | 同一工作區合成後複製 Report | 同一工作區合成後複製 Report，有時間標記避免舊報告 | 每點建立 00/01/02 來源與 setup 副本，在獨立目錄合成 |
| 面積與功耗解析 | 主要 slack／power；缺功耗時填 0 | 已解析面積、動態／漏電功耗，支援 W 至 pW | 延續明確單位換算，加入必要報告／網表／單位／DC 錯誤檢查 |
| timing 失敗 | 沒有獨立阻擋指標計算 | 標 TIMING_FAILED，但仍輸出計算值 | 標 TIMING_FAIL，保存原始數據，不填有效 TP／energy |
| 其他錯誤 | 檢查較少，繼續下一點 | 有 DC_FAILED／REPORT_MISSING／PARSE_FAILED，通常繼續 | 工具／報告錯誤即停止該版剩餘點，保留 ERROR 與原始資料 |
| netlist 保存 | 該腳本未逐點複製 netlist | 該腳本未逐點複製 netlist | 每點保留 V／DDC／SDC／SDF |
| 結果 | sweep_summary.csv | 每輪 CSV＋latest_summary.csv | sweep.csv＋request.json＋sweep_summary.json＋來源／完整原始報告 |

新流程沒有呼叫原 my_sweep.sh 或 sweep_dc.sh；它們仍保留在原 src 作歷史參考，不要同一輪混跑。

原 syn.tcl 與新 Tcl 也不完全相同：新流程統一四版 full/core 約束與活動假設，檢查 V1/V2/V3 保護 instance 數量；舊 parity syn.tcl 已有先 compile predictor 再保留的做法，新版延伸到四版。舊腳本含 set_fix_hold，新 paper_syn.tcl 目前沒有該呼叫；報告／命名／輸出位置也不同。因此歷史 PPA 與新版不能只歸因於 RTL 差異，正式比較應使用本次四版同流程重跑。

## 10 合成模型與數據計算

每個點使用相同 library/PVT、clock uncertainty 0.1、I/O 最大延遲 0.5T、input transition 0.5、output load 0.05 等條件；實際單位見 units.rpt／setup／SDC，不能自行推論為實體 post-layout 負載。

注入埠固定為 0，reset 排除正常 timing 路徑。輸入預設 static probability 0.5、toggle rate 0.1 per base-clock cycle；reset 固定 1、注入埠活動固定 0。activity.rpt 記錄顯式設定，後套用的列覆蓋前列；不聲稱報出內部傳播或測得真實訊息波形。

checking instances／predictors 在 uniquify 後先單獨 compile，再保留邊界；V0/V1/V2/V3 預期分別 0/5/29/2 個。這避免 protection 被無錯情況最佳化移除，但也構成最佳化限制，論文必須交代；不是用報告數量就證明合成後故障恢復正確。

| 指標 | 公式（T：ns，P：mW） |
| --- | --- |
| Full SHA3 吞吐 Gbps | 32768 / (4096-byte 訊息實測 cycles × T) |
| Standalone core rate 吞吐 Gbps | 1088 / (core start-to-done 實測 cycles × T) |
| Full 估計 energy/bit，pJ/bit | P_full / TP_full |
| Core 估計 energy/bit，pJ/bit | P_core / TP_core |
| 舊口徑對照 | P_full / TP_core；欄名 full_power_core_normalized_pj，不是完整訊息實測能耗 |

本機曾量得四版 4096-byte 7575 cycles／31 permutations，core 241 cycles；正式掃頻用工作站摘要值，不硬編碼。本次 241 包含介面計數定義，與舊 24×10=240 的純操作拍不同。full 與 core 的個別合成最佳化與端口不同，不能把兩者相減就稱為純外圍成本。

## 11 所有主要輸出檔案

### RTL 結果

`V*/results/rtl/時間/`：normal、ft、cross_lane、hamming_unit、hamming1600_unit、parity_unit、core 子目錄只建立該版適用者。

| 檔案 | 內容 |
| --- | --- |
| files.f | 該次測試真正使用的絕對路徑 filelist。 |
| compile.log | VCS 編譯命令與完整輸出。 |
| simulation.log | simv 命令、PASS／FAIL、量測與錯誤細節。 |
| simv／csrc／相關編譯產物 | 該項測試可執行檔與中間資料。 |
| build.log | 只有本機 Verilator 搭配自訂 C++ 編譯時才有；工作站 VCS 不需此檔。 |
| case_results.csv | 各 PASS 案例文字及可抽取量測欄位。 |
| latency.csv | 每訊息 bytes、端到端 cycles、permutations、core 累計 cycles。 |
| rtl_summary.json | 完整回歸狀態、log 路徑、量測與來源 SHA-256。 |
| FAILED.txt | 本輪失敗原因。失敗輪次不能當完整 PASS。 |
| 版本根目錄 rtl_latest.json | 完整通過時寫入的摘要副本，供掃頻查核。 |

### 掃頻結果

`V*/results/sweep/時間/`：

| 檔案 | 內容 |
| --- | --- |
| request.json | 本輪 version、periods、process、DC 執行檔、功耗方法、時間。 |
| rtl_summary.json | 本輪掃頻採用的 RTL 證據副本。 |
| synopsys_dc.setup | 本輪實際使用的製程設定副本（存檔名不帶前導點）。 |
| setup.log | Makefile 產生 setup 的 log；使用 --setup 時不會產生這份生成 log。 |
| sweep.csv | 每個 version/scope/period 一列，面積、功耗、slack、cycles、TP、energy、狀態與原始目錄。 |
| sweep_summary.json | 此輪是否有 full/core 有效點、工具錯誤數、整體狀態；不是全域最佳點分析報告。 |
| full_10ns、core_10ns 等目錄 | 每點實際來源副本與輸出。來源包含 00/01/02，不要當成多個需手動維護的專案。 |
| 每點 02_SYN/dc.log | 真正 DC 完整輸出；外層 sweep_logs 只有進度與摘要。 |

每點 Report/：

| 檔案 | 用途 |
| --- | --- |
| pre_compile.check | compile 前 check_design 輸出。 |
| check_design.rpt | compile 後設計一致性檢查。 |
| check_timing.rpt | timing 約束檢查；已移除不支援的 -verbose。 |
| area.rpt | 階層面積。 |
| power.rpt | 功耗總表；解析 dynamic 與 leakage 的明確單位。 |
| power_hierarchy.rpt | 階層功耗。 |
| timing.rpt | 最多 20 條 timing paths 與 nets／transition／capacitance。 |
| constraints.rpt | 所報約束違反項目；VALID 也要求沒有 VIOLATED。 |
| qor.rpt | 合成品質概況。 |
| clocks.rpt | clock 定義。 |
| ports.rpt | 端口相關資料。 |
| references.rpt | 階層 reference／cell 使用資料。 |
| design.rpt | 設計／環境概況。 |
| libraries.rpt | 載入的 libraries。 |
| activity.rpt | 顯式輸入活動假設紀錄；不是 report_switching_activity 或 SAIF/VCD 量測。 |
| units.rpt | library／設計單位；目前 DC 格式 Time_unit : 1.0e-09 Second(ns) 已支援。 |
| protection_instances.csv | 被保留的 checking instance、reference、mapped area。 |
| run_metadata.txt | version、scope、period、最差 slack、功耗模型、保護數與 library 名稱。 |
| COMPLETE | Tcl 走到最後的完成標記；不代表沒有 Error，也不代表 timing 通過，仍需 Python 查報告。 |

每點 Netlist/：`*_SYN.v` 是 mapped Verilog；`*_SYN.ddc` 是 DC 設計資料庫；`*_SYN.sdc` 是約束；`*_SYN.sdf` 是延遲資料。保留這些供追溯，不代表已做 gate-level simulation／post-layout／formal equivalence。

## 12 狀態、目前修正與接下來怎麼做

VALID：必要資料與檢查通過且 slack 非負；TIMING_FAIL：slack 負，保留資料但不列有效 TP／energy；CONSTRAINT_FAIL：slack 非負但其他所報 constraints 違反；ERROR：工具／報告／單位等錯誤，該版停止後續點。

`units.rpt` 的 Power_unit=N/A 不會被當成功耗為零；功耗數字另讀 power.rpt。時間單位解析現在將科學記號秒值換成 ns，仍只接受等價 1 ns，不會偷偷忽略真實不同的 time unit。

目前完整版已包含四版 run_sweep.py 與 paper_syn.tcl 的相容修正。使用者已回報試跑通過；新建工作區直接使用完整版，不需再套補丁。00/01 不變，不需重跑 RTL。先跑 V0 的 10 ns full/core，確認完整成功後再啟動四版 dense sweep。失敗輪次保留，不會自動續接或自動重試；每次執行會建立新的時間戳目錄。

最佳操作點也不是新 Python 已經替你做的所有分析：目前提供各點 CSV。之後在 VALID 點中找最低估計 energy/bit；最短可用 period 與鄰接負 slack 點給 0.1 ns 邊界，必要時再細掃。不把所有錯誤都當 timing 失敗，也不宣稱離散網格找到了全域精確極限。
