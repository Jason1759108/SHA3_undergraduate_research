# 完整 RO 波形路徑怎麼看

預設 TESTBED_PUF 現在實例化 puf_ro_top、ro_array_model 與 PATTERN_PUF_WAVE。執行原工作站 01 流程，或 `make -f Makefile.ro wave`，得到 puf_sim.vcd。

Windows：`run_local.ps1 -Mode wave`，波形在 `.build/wave/puf_sim.vcd`。預設 all 包含 wave/count/ro/ecc 四組。

## 第一層：正常操作

加入 TESTBED_PUF 的 clk、rst_n、start、phase、ready、busy、done、result_valid、result_ready、key_valid、helper_valid、key_data、helper_in、helper_out、corrected_count。

command_text/error_text/status_text 設 ASCII；資料設 Hex，phase/計數設 unsigned decimal。

外部 Command/Bitmap/helper 的介面與前版相同，仍在 start&&ready 上升沿鎖存；結果等待 result_ready，不是每次 key_valid 高就代表一筆新結果。

## 第二層：RO 到 Counter 的真實量測鏈

加入同一頂層的：

```text
req, mready, mvalid, pair_index
selected_ro_a, selected_ro_b, counter_reset_n
ca, cb
dut.backend.state, dut.backend.selected_pair
```

1. req&&mready 接受要量測的 pair_index。
2. backend.selected_pair 鎖存新配對，counter_reset_n=0；此時才允許切換。
3. 啟用對應兩個 RO，selected_ro_a/b 出現數 ns 週期的振盪。
4. 等待穩定，counter_reset_n=1，Counter 再做 reset release 與 warm-up。
5. 約 1000ns 的量測窗後，mvalid=1，ca/cb 有效；每個選中配對共重複 5 次。
6. 回應後停用 RO、Counter 再次 reset，才接受下一筆。

backend.state：0 IDLE、1 SETTLE、2 COUNTER_START、3 COUNTER_WAIT、4 DELIVER。pair_index 是請求索引，selected_pair 是本筆量測的鎖存索引。

**這裡的 ca/cb 由計數器數 selected_ro_a/b 產生，不是 puf_count_model 給的數字。** 模型的快速週期約 3.0..3.4ns、慢速約 5.0..5.4ns，因此 1000ns 窗內約 294..333 / 185..200 次。方向依人工晶片特徵決定。Pattern 對每一筆結果用週期算預期計數，容許 ±2。

波形橫軸可能是 ps；1,000,000ps=1us。一份完整回應有 1280 次量測，需約 1.5ms；要看 RO 細節需放大到 ns，要看整份輸出需縮到 ms。

## Phase

| phase | 案例 |
|---:|---|
| 1 | Registration，輸出與 GOLD_RAW/GOLD_HELPER 相符；結果背壓保持 |
| 2 | Certification，得到相同資料，無 helper 輸出 |
| 3 | Reset 後用外部 helper 重建 |
| 4 | 16 組 RO 快慢交換造成分散位元翻轉，ECC 修回原資料 |
| 5 | 同一 ECC 區塊兩個翻轉，拒絕 |
| 6 | 一個選中配對改為相同頻率，PUF_WEAK_PAIR |
| 7 | 一個選中 RO 停振，backend.ro_fault=1，計數轉成相等零值後拒絕 |
| 8 | 不同 Bitmap 註冊，覆蓋最後候選配對 |
| 9 | 不同 Bitmap 重建，得到其對應資料 |
| 10 | 正在計數時 reset，之後重新提供輸入並恢復 |

真正的實體 RO 還需平台元件與實測；ro_array_model 的 delay/seed 只是可重現的人工 fixture。模型採兩個 active waveform processes 模擬目前啟用的配對，不排程未啟用的 638 路；不模擬 PVT、熱耦合或真實製程分佈。

## 波形大小與深度

預設不記錄整個 640-bit 高速 bank，避免每個 RO edge 都輸出寬向量；保留選中的兩路 scalar 波形。Verilator wave 模式 trace depth=2；VCS dumpvars 列出必要訊號。完整波形仍可能約 250MB，因為包含約 12ms 的 ns 級時脈。可由 sample_results/wave/phases.csv 快速定位各 phase。

要看 Counter 內部 bin/Gray/synchronizer，先跑獨立 TESTBED_RO（較短）；或調高 wave 模式 trace depth 並注意檔案大小。
