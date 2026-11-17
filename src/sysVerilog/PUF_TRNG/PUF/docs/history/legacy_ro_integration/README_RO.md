# RO／Counter／PUF 完整路徑

本次以你目前實際資料夾為基準，保留 TESTBED_PUF/PATTERN_PUF 的命名、原本工作站 Makefile 與 syn.tcl。預設 filelist.f 改為完整波形路徑；原先直接輸入 count 的完整 Pattern 保留在獨立 count 測試。

## 新增的數位整合

```text
ro_array_model（640 路人工延遲振盪訊號，只有選中的兩路啟動）
             ↓ ro_signals[639:0]
puf_ro_top
  ├─ puf_device：原先兩命令、外部 Bitmap/helper、ECC、結果握手
  └─ ro_measure_backend
       ├─ 鎖存 pair_index，選 RO 2i 與 RO 2i+1
       ├─ Counter reset 期間切換配對、啟用 RO，等待 SETTLE_CYCLES
       └─ ro_frequency_counter：真正計數、Gray 同步、固定窗差值
             ↓ count_a/count_b + valid
        puf_device 內的 PUF 核心
```

此路徑沒有 puf_count_model，也沒有從 seed 直接計算 count。RO 模型只提供有延遲的 0/1 波形，所有計數來自 ro_frequency_counter。320 候選／256-bit 回應／80-bit helper、命令與輸出握手保持相同。

## 使用方式

你原來的 `01` 流程若讀取 `00_TESTBED/filelist.f`，現在會執行新的 TESTBED_PUF；也可以：

```sh
cd 00_TESTBED
make vcs_rtl                 # 既有工作站 Makefile，不改動
# 或用新增的獨立入口
make -f Makefile.ro wave     # 完整波形 → counter → PUF
make -f Makefile.ro count    # 保留的直接 count 模型故障測試
make -f Makefile.ro ro       # counter 單元測試
make -f Makefile.ro ecc      # ECC 單元測試
```

每份 manifest 都只有一個自動 top，不需手動註解／解除其他 top。預設完整測試的波形是 puf_sim.vcd；count 測試是 puf_count_sim.vcd。

本機 Windows 已提供 run_local.ps1：`-Mode wave`（或 puf）跑完整波形；count/ro/ecc 可分開跑，all 跑四組。工具路徑可覆寫。Python runner 只獨立核對預期答案，不會把 count 值餵進波形路徑。

## 時序與安全切換

1. req&&ready 上升沿接受配對，先保持 Counter reset。
2. 選擇新配對，啟用兩個 RO，等待預設 4 個系統 clock。
3. 釋放計數器 reset；RO-domain reset 以兩級同步器釋放。
4. Counter 再等待預設 5 個 system clock，建立 Gray 同步與量測起點。
5. 量測預設 100 個 clock，約 1000ns，鎖存兩個計數值。
6. 回覆 measure_valid；PUF 取走結果後停用 RO、再次 reset Counter。

切換 clock 的期間 Counter 必須在 reset，選擇訊號在量測期間固定。這避免模擬中的 mux 切換邊沿混入有效計數；不代表已完成實體 clock mux/glitch/CDC signoff。

MEASURE_TIMEOUT 必須大於 settle+warm+window+控制延遲，top 有參數檢查。每個窗邊沿數須小於 65536；模型約 185..333，使用不同實體頻率／視窗時須重新評估。

若任一 RO 在窗內沒有計數，backend.ro_fault=1，回傳相等的零計數，讓核心以 PUF_WEAK_PAIR 拒絕；不會把停振的 RO 判成可靠 bit。

## 實體 RO 的完成邊界

新增 ro_cell.sv、ro_array.sv、puf_ro_chip_top.sv 是**結構式硬體模板**：奇數級反相器環，帶 enable；沒有 seed 或人工延遲。完整實體連接為 RO array → puf_ro_top。

**這不是已在特定 FPGA／ASIC 驗證的 RO IP。** 通用 RTL 的組合回授迴路不能放進零延遲功能模擬，也可能被合成器重寫或刪除。必須依目標換成實際 LUT primitive 或 standard-cell 實例，設定 preserve/dont_touch、允許回授迴路、佈局與繞線約束，再量測頻率、穩定性與熵。檔案中的屬性只是模板，不宣稱所有工具都會遵守。

因此實體模板不放入預設 RTL 模擬清單；功能模擬使用可控制延遲的 ro_array_model。真正製程差異及 PUF 唯一性仍需硬體量測，不能以模型 seed 當成證明。

## 合成

原 syn.tcl 保留。它目前仍是 SHA3 專用內容，不能拿它宣稱已合成新的 PUF top。新增 `02_SYN/syn_puf_ro.tcl` 專供 digital puf_ro_top，讀 rtl_digital.f，實體 RO 模板不納入。需要真實 library：

```sh
cd 02_SYN
TARGET_LIBRARY=/path/to/library.db dc_shell -f syn_puf_ro.tcl
```

腳本含 640 個 RO 輸入時脈的範例約束，假定預設 320 候選。實際頻率、Gray bus skew、RO mux、reset recovery/removal、同步器佈局與全路徑 STA 都需製程／FPGA 工具 signoff。本機沒有 DC／VCS 或製程庫，未產生經驗證的 mapped netlist。

本次沒有加入 SHA3 或認證；SECDED 三錯誤誤解碼的限制仍存在，原 count 測試保留這個案例。
