# SHA-3 Lane Hamming Detection & Recovery 分工說明

本文件對應 **Candidate 3（lane-serial + `lane_active[24:0]`）** 的下一步實作。規格來源是 `FT論文導讀與算法講義.md` **第六、七部分的完整版**：

> 每個 64-bit lane 一顆 **(72,64) SECDED**。寫入 encode、寫完／讀出 decode。`lane_active=0` 的 20 條不跑編解碼樹。**1-bit 當拍翻回，不多跑 θ/χ。** **只有 SECDED 判成 2-bit（`UNCORR`）才做 dependency replay**（χ 重算 1 row；θ 依 `D[]` 是否可信重算 1 col、重做 C/D、或從 col0 重跑）。

不做 `FT_OFF` / `FT_LANE` / `FT_STATE1600` 切換，也不做 1600-bit Hamming 對照組。本 repo 的 `src/` **只維持一份 RTL**：就是已經壓完效能、推上 GitHub 的 Candidate 3。無保護對照用 GitHub 上那個 commit，**不要**在專案裡再複製一份程式碼。之後 FT 直接改這份 `src/sysVerilog/`。

兩人角色沿用 `others/分工說明.md`：

| 角色 | 負責軸 |
| --- | --- |
| **Person A** | 架構、state bank 旁的校驗儲存、gating 連動、排程、Hamming 編解碼、region 決策 |
| **Person B** | θ / χ 的 replay 行為、top 接線、fault injection TB、hash 回歸 |

開發原則與原本相同：**Phase 1 兩人一起定介面與 bit 排法；之後各自寫模組，只靠合約對接；最後一起接 `TESTBED`。** 改 RTL 時不要兩人同時改同一個 `.sv`。

**不要** 為了 recovery 去做「χ start 同時寫兩列」、整包 TMR、或把 FT 寫進 pad / absorb / formatter。Fault 範圍只做 **Keccak-f 的 240 cycle**。

---

## 0. 現況碼與 FT 改哪裡

1. `src/sysVerilog/` 現況 = GitHub `main` 上壓完效能的版本（10 cycle × 24 round = 240）。**沒有容錯**；本專案也不另存第二份 RTL。
2. Lane-aware detection / recovery 之後 **直接改** 這份 `01_RTL`（θ、χ、scheduler、top、pkg，以及新加的 Hamming／ecc／region 檔）。不要開第二套 top、不要用 parameter 切保護開或關。
3. 無注入時行為必須和現況相同：一 round 仍 10 cycle、keccak-f 仍 240 cycle、原 `PATTERN.sv` 仍全過。能量若要對無保護版，用 GitHub 上該 commit 再跑一次 `sweep_dc.sh`，不要在 `others/` 複製 `.sv`。

---

## 總覽：Phase 與可否並行

| 開發階段 | 執行方式 | Person A | Person B | 階段目標 |
| --- | --- | --- | --- | --- |
| **Phase 1** | 必須同步 | `sha3_pkg.sv`、Hamming 位置表寫進 pkg | 同一份 pkg、同一張位置表 | 鎖定常數、enum、72-bit 排法；後面不准再改 port 意義 |
| **Phase 2** | 獨立並行 | `keccak_hamming64.sv`、`keccak_lane_ecc.sv` | `tb_hamming64.sv` | 編解碼單元單測全過；還不接 θ/χ/top |
| **Phase 3** | 獨立並行 | `keccak_ft_region.sv`、`keccak_round_scheduler.sv`；θ 的 `D[1:4]` 校驗 FF 接線規格 | `keccak_theta_serial.sv`、`keccak_chi_row.sv` 加 `replay` | 1-bit 不進 FSM；`UNCORR` 才重算且不前進 `col`/`cnt` |
| **Phase 4** | 最後一起接 | `filelist.f` / `syn.tcl` 加新檔；確認 gating 仍只開 5 個 `lane_clk` | `sha3_ultra_low_power_top.sv`、`PATTERN_FT.sv` | 無注入回歸全過；1-bit Δ=0；2-bit 才 replay 且 hash 對 |

> **開發原則：** Phase 1 絕對要兩人一起定案。Phase 2 與 Phase 3 可依各自節奏獨立推進，請嚴格遵守 Hamming `status` 與 `replay` 合約。全部單元完成後再一起進入 Phase 4，接既有 `00_TESTBED/TESTBED.sv` + 原 `PATTERN.sv`，另加 `PATTERN_FT.sv` 做注入。

現況一 round（FT 必須掛在這些拍上，不要假設舊的 17 / 11 cycle）：

| Cycle | 排程 | 運算 | `lane_active` |
| --- | --- | --- | --- |
| 1 | `SCHED_THETA_START` | 算 C/D，寫 col0，鎖 `D[1:4]` | col0 五個 lane |
| 2–5 | `SCHED_THETA_WAIT` | 寫 col1–4，cycle 5 `theta_done` | 該 column |
| 6 | `SCHED_CHI_START` | ρπ 是 wire；row0 χ + ι；鎖 frozen row1–4 | row0 |
| 7–10 | `SCHED_CHI_WAIT` | row1–4 χ，cycle 10 `chi_done` | 該 row |

`LANE_IDX = y * 5 + x`。ρ/π 0 cycle。ι 只在 cycle 6 的 `lane(0,0)`。第 24 round 後多 1 拍 `SCHED_DONE`，**不算進 240**。

---

## 算法（實作時就照這裡寫）

### A. (72,64) SECDED 碼字排法

資料 64 bit，Hamming 校驗 7 bit，全體偶校驗 1 bit，共 72 bit。位置用 **1-indexed**（和課堂 (7,4) 同一套），寫死在 `sha3_pkg`，兩人禁止一人從 0 編、一人從 1 編。

72 個位置裡：

| 位置 | 角色 |
| --- | --- |
| 1, 2, 4, 8, 16, 32, 64 | Hamming 校驗 \(P_1,P_2,P_4,P_8,P_{16},P_{32},P_{64}\) |
| 72 | 全體 even parity \(P_{\mathrm{ext}}\)（對位置 1..71 再 XOR） |
| 其餘 64 個 | 資料 \(d_0\ldots d_{63}\)，依位置編號由小到大依序塞入 |

資料位置就是跳過 2 的冪次之後剩下的：3, 5, 6, 7, 9, …, 71。pkg 裡用兩個 function 固定對照，encode / decode / TB 都叫它們，不要在三個檔各寫一份 if-else：

```systemverilog
// d = 0..63 → 位置 3..71（跳過 1,2,4,8,16,32,64,72）
function automatic int ft_data_pos(input int d);
function automatic int ft_pos_is_ham_p(input int p); // p∈{1,2,4,8,16,32,64}
```

硬體 bus 建議（MSB 在左，方便波形）：

```text
code[71]    = 位置 72 = P_ext
code[70:0]  = 位置 71 .. 位置 1
```

也就是 `code[k] ↔ 位置 (k+1)`，`code[71] ↔ 位置 72`。檔頭註解必須寫這句。

### B. Encode（純組合）

輸入 `data[63:0]`，輸出 `code[71:0]`。

1. 72-bit 暫存 `w` 先清 0。把 `data[d]` 放到位置 `ft_data_pos(d)`。七個 Hamming 位與 \(P_{\mathrm{ext}}\) 先放 0。
2. 對每個 \(p \in \{1,2,4,8,16,32,64\}\)：
   \[
   P_p = \bigoplus_{\{j \in 1..71 \mid (j\ \&\ p)\neq 0,\ j\neq p\}} w[j]
   \]
   偶校驗：這組 XOR 結果就是 \(P_p\)，寫回位置 \(p\)。
3. \(P_{\mathrm{ext}} = \bigoplus_{j=1}^{71} w[j]\)（含七個 Hamming 位），寫入位置 72。

對 (7,4) 這就是講義裡 P1/P2/P4 那三組；這裡只是把組加成七組。

### C. Decode 與 status（純組合）

輸入收到的 `code[71:0]`。

1. 用 **收到的值** 重算七組 Hamming XOR（這次 **包含** 位置 \(p\) 自己）：
   \[
   s_p = \bigoplus_{\{j \in 1..71 \mid (j\ \&\ p)\neq 0\}} \mathrm{code}[j]
   \]
2. syndrome 整數
   \[
   S = s_1 + 2s_2 + 4s_4 + 8s_8 + 16s_{16} + 32s_{32} + 64s_{64}
   \]
   範圍 0..127，有效指向最多到 71。
3. 全體
   \[
   p_{\mathrm{all}} = \bigoplus_{j=1}^{72} \mathrm{code}[j]
   \]
   \(p_{\mathrm{all}}=0\) 表示 72 bit 仍是偶數個 1。

**判定表（必須照這張，不准猜）：**

| \(S\) | \(p_{\mathrm{all}}\) | `status` | 動作 |
| --- | --- | --- | --- |
| 0 | 0 | `FT_ST_OK` | `data_out` = 抽出的 64-bit，不翻 |
| 0 | 1 | `FT_ST_CORRECTED` | 只有 \(P_{\mathrm{ext}}\) 錯，翻 `code[71]`，資料不變 |
| 1..71 | 1 | `FT_ST_CORRECTED` | 翻位置 \(S\) 那一 bit，再抽出 64-bit |
| 1..71 | 0 | `FT_ST_UNCORR` | 典型 2-bit：**不准翻**，`data_out` 可隨便但 **禁止** 當正確值寫回 |
| ≥72 或其它 | * | `FT_ST_UNCORR` | 當 2-bit / 不可解 |

為什麼 2-bit 時 \(p_{\mathrm{all}}=0\)：兩個錯讓全體 parity 互消，但 Hamming 組仍會得到一個「假的單顆位置」。若照 \(S\) 去翻，會變成第三個錯。所以 `UNCORR` 時硬體只能拉旗號，把資料丟掉重算。

1-bit 翻的對象包含 **資料位或校驗位**。校驗位自己中彈：\(S\) 會指到 1/2/4/…/64，翻完資料 64-bit 應不變。

### D. 接到 lane-serial 上（detection，講義 §6）

每條 lane 仍是 64 個資料 FF（`keccak_state_bank` 維持現況）。旁邊多 **8 個校驗 FF**，跟該 lane 的 `lane_clk[i]` 同一拍寫。睡著的 lane 沒有 posedge，校驗也不更新。

每一拍最多 5 條 `lane_active=1`：

```text
θ/χ/absorb/clear 算出 nxt 的 64-bit data
    → 僅對 active lane：encode → 可選 TB 注入翻 bit → decode
         ├── OK / CORRECTED  → 把 data_out 當 nxt 寫入；ecc 用「修正後再 encode」的 8 bit
         └── UNCORR          → fault_valid=1；該拍寫入不可信，下一拍 replay 覆寫
    → inactive 20 條：encode/decode 輸入 AND 成 0（operand isolation）
```

**1-bit 必須走「寫入前 decode」**：注入發生在 encode 之後、FF 之前，decode 翻完再進 `nxt_state`。這樣 1-bit **不會** 進 FSM，extra cycle = 0。  
**2-bit** 同拍可能已經把錯碼寫進 FF（或你選擇 UNCORR 時不開 `lane_clk`）；下一拍 `replay=1` 用同一 index 再算、再 encode 覆寫。同一處最多 replay 1 次。

Clear / absorb 也要 encode（否則之後 θ 讀到的 lane 沒有合法碼）。Fault injection **只在** keccak-f 且 `lane_active=1` 時做；pad/absorb 不算本季 fault 範圍。

**限制（報告可講、RTL 不必解）：** 沒在寫的 lane 若 retention 被打到，當拍不 decode 就看不見。閘算錯但寫出去的碼「自洽」時 Hamming 會認為 OK——這不是 register SECDED 的能力。

### E. Recovery（講義 §7）

只由 `status==UNCORR` 觸發。`CORRECTED` 當沒事。

時序：

```text
Cycle T  : 本體算完、decode 出 UNCORR、fault_valid=1
Cycle T+1: replay=1，θ/χ 的 col/cnt 不前進，再開同一組 5 個 lane_clk，覆寫
           然後 index 才前進
```

`round_index` replay 時不准加。`chi_done && round_index==23` 若與 `fault_valid` 同拍，必須先 replay 再進 `SCHED_DONE`。

#### χ：永遠只重算 1 row

\[
B[x,y,z]=A[x,y,z]\oplus\big(\neg A[x+1,y,z]\land A[x+2,y,z]\big)
\]

不看其他 row。本拍 `lane_active` 本來就是 row \(y\) 的 5 個 lane。

- `replay=1` 時 **禁止** 再執行 `if (start) frozen_state <= in_state`。row1–4 繼續讀已鎖的 `frozen_state`。
- `cnt` 保持當前 row。row0 重算時 ι 仍 XOR **同一個** `round_index`。
- 重算完五個 lane 再 encode 寫回。下一拍 `cnt` 才 +1。

#### θ：三種 replay，由 `keccak_ft_region` 輸出，θ 本體照做

現況 RTL：

- Cycle 1：`compute_d=1`，用更新前 state 算完全部 `C_comb`/`D_comb`，寫 col0（`A'[0,y] ^= D_comb[0]`），posedge 鎖 `D[1:4]`。
- Cycle 2–5：`A'[c,y] ^= D[c]`，這裡的 \(A\) 仍是 θ 開始前的值。

`D[]` 不依賴「col0 已經寫回」。寫欄錯和算 D 錯要分開。

**`D[1:4]` 也各掛一顆同一個 `keccak_hamming64`。** 只在 `compute_d` 那拍 encode 寫入；之後 UPDATE 讀 `D[c]` 前 decode。沒有這四顆碼，錯的 `D` 會讓整欄寫出「碼自洽的錯資料」，lane Hamming 看不到，講義裡的 FROM0 也觸發不了。

決策（`fault_src=THETA`）：

| 條件 | `ft_replay_e` | θ 行為 |
| --- | --- | --- |
| `D[col]` decode 為 OK/CORRECTED，只有寫入 lane `UNCORR` | `FT_REPLAY_THETA_COL` | `col` 不前進，再做 `in XOR D[col]`，再開該欄 5 個 clock |
| Cycle 1（`compute_d`）且（C/D 路徑 `UNCORR`，或 col0 有 ≥2 條 lane `UNCORR`） | `FT_REPLAY_THETA_CD` | 等同再做一次 start 拍：重算 `C_comb`/`D_comb`、重寫 col0、重鎖 `D[1:4]` 並重 encode |
| 已進入 col1–4，且 `D[col]` 為 `UNCORR`（修不了） | `FT_REPLAY_THETA_FROM0` | 重算 C/D，從 col0 重寫到 col4（最多再 5 拍） |
| χ 任一 active lane `UNCORR` | `FT_REPLAY_CHI_ROW` | 見上 |

`D` 若只是 1-bit：decode 翻回後當正確 `D` 用，**不要** 因此 replay。

同一 round 最多注入 1 次（TB 保證），所以不需要 replay 再失敗的狀態機；硬體仍應把第二次 `UNCORR` 拉 `fault_valid` 但不準迴圈死轉（建議 replay 中的 `UNCORR` 只計 log、仍前進，避免卡死）。

---

## 模組詳細分工與 I/O

### Phase 1: 合約（兩人共同，必須同步）

* **共同撰寫：`sha3_pkg.sv`**
* **新增常數：**

```systemverilog
localparam int FT_DATA_W = 64;
localparam int FT_HAM_P  = 7;
localparam int FT_EXT_P  = 1;
localparam int FT_CODE_W = FT_DATA_W + FT_HAM_P + FT_EXT_P; // 72
```

* **新增 enum：**

```systemverilog
typedef enum logic [1:0] {
    FT_ST_OK         = 2'd0,
    FT_ST_CORRECTED  = 2'd1,
    FT_ST_UNCORR     = 2'd2
} ft_status_e;

typedef enum logic [2:0] {
    FT_SRC_NONE,
    FT_SRC_THETA,
    FT_SRC_CHI
} ft_src_e;

typedef enum logic [2:0] {
    FT_REPLAY_NONE,
    FT_REPLAY_THETA_COL,
    FT_REPLAY_THETA_CD,
    FT_REPLAY_THETA_FROM0,
    FT_REPLAY_CHI_ROW
} ft_replay_e;
```

* **新增 function：** `ft_data_pos(d)`、以及（可選）`ft_code_bit(code, pos)` 方便取 1-indexed 位。位置表與 §算法 A 必須一致。
* **排程約定（Phase 3 才實作，enum／語意見在就定）：** 不新增大堆 `SCHED_*`。θ/χ 各加 `input replay`：`replay=1` 時不要前進 `col`/`cnt`，用同一 index 再算並再拉 `lane_active`。排程器只在 `fault_valid`（來自己經 OR 過的 `UNCORR`）時把 `theta_replay` 或 `chi_replay` 拉 1 拍（FROM0 可連拉多拍直到 θ 自己 `done` 重出）。`theta_start` / `chi_start` 不要重發整段。
* **不改：** 主 FSM enum、RC、RHO、PI。

Phase 1 結束前兩人在 pkg 檔頭用註解貼一份「位置 1..72 角色」；後面 Hamming 與 TB 都對這份。

---

### Phase 2: Hamming 單元（獨立並行）

還不准改 scheduler、θ、χ、top。原 `PATTERN.sv` 必須仍全過。

👨‍💻 **Person A**

* **`keccak_hamming64.sv`（新檔）**
* **I/O：**

```text
input  logic [63:0] data_in
output logic [71:0] code_out

input  logic [71:0] code_in
output logic [63:0] data_out
output logic [6:0]  syndrome
output logic        ext_fail
output ft_status_e  status
```

可做成兩個 module（`keccak_hamming64_enc` / `_dec`）或同一檔兩個 always_comb。純組合，無 clock。
* **改法：** 嚴格照 §算法 B、C。`syndrome` 輸出 7-bit `{s64,...,s1}`；`ext_fail = p_all`。
* **注意：** `data_out` 在 `UNCORR` 時不要被拿去寫 state；由 lane_ecc / top 看 `status` 擋。

* **`keccak_lane_ecc.sv`（新檔）**
* **I/O：**

```text
clk, rst_n
input  logic [24:0] lane_clk          // 與 state_bank 同一組 gated clock
input  logic [24:0] lane_active
input  state_t      data_nxt          // 寫入前的 64-bit（θ/χ/absorb/clear mux 後）
input  logic [24:0] inject_en         // 合成綁 0；TB 才用
input  logic [71:0] inject_mask [0:24] // 或改成「只對一個 lane 注入」省 port
output state_t      data_wr           // decode 後要進 bank 的 64-bit
output logic [7:0]  ecc_q [0:24]      // 可內部自用，不一定接到 top
output ft_status_e  status [0:24]
output logic        any_uncorr
output logic [24:0] uncorr_mask
```

* **改法：** 25 路 generate。`lane_active[i]==0` 時該路 `data_in`/`code_in` AND 成 0。active 路：`code = encode(data_nxt)` → `code ^= inject` → decode → `CORRECTED/OK` 時 `data_wr` 用 `data_out`，校驗 FF 存 **修正後再 encode** 的 8 bit（避免留下已翻過的髒碼）。`UNCORR` 時 `any_uncorr=1`，`data_wr` 建議保持 `cur` 或仍寫但由 replay 覆寫；兩人 Phase 1 定一種，建議 **UNCORR 不開該 lane 的有效寫入**（該拍 `data_wr=cur` 且不要讓 ecc 更新），避免把 2-bit 髒碼存進去。
* **注意：** 校驗 FF 的 clock 必須是 `lane_clk[i]`，不是全域 `clk`。不要把 25 路 Hamming 樹都接在 ungated clock 上空轉。

`keccak_state_bank.sv`、`sha3_low_power_gating.sv`：Phase 2 **不改**。資料 64-bit 路徑維持原 bank。

👨‍💻 **Person B**

* **`00_TESTBED/tb_hamming64.sv`（新檔，不進正式 PATTERN、不進合成）**
* **任務：** 實例化 `keccak_hamming64`，對 Phase 1 的位置表做窮舉。
* **向量：**
  * `data=0`、`64'hFFFF_FFFF_FFFF_FFFF`、`64'hDEAD_BEEF_0123_4567`、隨機 ≥20 組。
  * 每個 data bit 翻 1 次 → 必須 `FT_ST_CORRECTED` 且 `data_out` 復原、`syndrome` 指到對應 **位置**（不是 data index 本身）。
  * 每個校驗 bit（7 個 Hamming + 1 個 ext）翻 1 次 → 資料不變、仍是 `CORRECTED`。
  * ≥20 組 2-bit（兩顆 data、一顆 data+一顆校驗、兩顆校驗）→ 必須 `UNCORR`，**禁止** `data_out` 被當成另一個合法碼。
* **注意：** 注入是對 72-bit codeword 翻，不是對 data 翻完再 encode（那樣碼仍合法、測不到 decode）。

**Phase 2 結束：** `tb_hamming64` 全過；`filelist.f` 先不要接進 top。

---

### Phase 3: Replay 控制與 θ/χ（獨立並行）

👨‍💻 **Person A**

* **`keccak_ft_region.sv`（新檔，純組合）**
* **I/O：**

```text
input  ft_src_e     src            // 本拍是 θ 還是 χ 在寫
input  logic        theta_compute_d
input  logic [2:0]  theta_col
input  logic [2:0]  chi_cnt
input  logic [24:0] uncorr_mask
input  ft_status_e  d_status [1:4] // D[1:4] 的 decode；cycle1 用 D_comb 的 decode
output ft_replay_e  replay_kind
output logic        fault_valid    // 1 僅當存在 UNCORR 且需要 replay
```

* **改法：** 照 §算法 E 決策表。`fault_valid` **不得** 因 `CORRECTED` 拉高。
* **注意：** χ 不看 `d_status`。θ UPDATE 時 `col∈1..4` 才看 `d_status[col]`。

* **`keccak_round_scheduler.sv`**
* **現況 I/O：** `clk, rst_n, start_process, theta_done, chi_done` → `theta_start, chi_start, round_index, process_done`。
* **新增：** `input logic fault_valid`、`input ft_replay_e replay_kind`、`output logic theta_replay`、`output logic chi_replay`。
* **改法：** `SCHED_THETA_WAIT` / `SCHED_CHI_WAIT` 看到 `fault_valid` 時維持 WAIT，對應 `*_replay` 拉高；`theta_done`/`chi_done` 若與 `fault_valid` 同拍，**先 replay 再認 done**。`round_index` 只在「`chi_done` 且沒有 pending replay」時 +1。
* **注意：** 不要重發 `theta_start`/`chi_start` 來做 replay（χ 會重鎖 `frozen_state`）。`sha3_ctrl_fsm.sv` **不動**。

θ 的 `D[1:4]` 校驗：Person A 在 Phase 3 把「D 也走 `keccak_hamming64`」的接線規格寫進註解／小 wrapper；實際 `always_ff` 仍在 `keccak_theta_serial.sv` 裡由 Person B 加（避免兩人同改 θ）。合約：每顆 `D[x]` 旁 `logic [7:0] D_ecc[1:4]`，只在 `compute_d` 更新；UPDATE 讀之前 decode。

👨‍💻 **Person B**

* **`keccak_theta_serial.sv`**
* **現況 I/O：** `in_state, clk, rst_n, start` → `out_state, done, lane_active`。
* **新增：** `input logic replay`、`input ft_replay_e replay_kind`；以及給 region 用的 `output logic compute_d`、`output logic [2:0] col`、`output ft_status_e d_status [1:4]`（或把 D 的 72-bit 送到 top 再解——較髒，建議 θ 內解）。
* **改法：**
  * `FT_REPLAY_THETA_COL`：`nxt_col = col`，FSM 留在 `THETA_UPDATE`（cycle1 則再走一次 `compute_d` 寫 col0 但不重鎖錯的控制：COL 在 cycle1 只重寫 col0，**不要** 把已經對的 `D[1:4]` 洗掉）。
  * `FT_REPLAY_THETA_CD`：再做一次 start 拍（`compute_d`、寫 col0、鎖 `D[1:4]`）。
  * `FT_REPLAY_THETA_FROM0`：重算 C/D 後 `col` 回到 0 的寫入條件，然後照常 1–4。
  * `replay=0` 時行為與 baseline 逐行相同（含 `compute_d` operand isolation、不存 `D[0]`）。
* **注意：** `done` 在 replay 拍必須為 0。C_comb 樹仍只在 `compute_d` 打開。

* **`keccak_chi_row.sv`**
* **現況 I/O：** `in_state, clk, rst_n, start, round_index` → `out_state, done, lane_active`。
* **新增：** `input logic replay`。
* **改法：** `replay` 時 `cnt_next = cnt`，FSM 留在當前（IDLE+start 那拍 replay 則再算 row0，但 **`if (start) frozen<=in_state` 在 replay 時關閉**）。row0 的 ι 繼續用輸入的 `round_index`。
* **注意：** 這是最容易寫錯的一行。Pi 跨 row，重鎖 frozen 會吃到已經被 χ 寫過的 `cur_state`。

`keccak_iota.sv`、`keccak_rho_pi_wire.sv`：**不改**。

**Phase 3 結束：** 無注入時 θ 5 拍、χ 5 拍、handshake 與現在相同。可用獨立小 TB 或波形確認：`replay=1` 時 `lane_active` 仍是同一 row/col 的 5 bit。

---

### Phase 4: Top 與注入（最後一起接）

👨‍💻 **Person B 主筆 top / PATTERN；Person A 同一天改 filelist 與 syn**

* **`sha3_ultra_low_power_top.sv`**
* **改法：** 只加實例化與 mux，不在 top 寫 θ/χ 公式、不寫 Hamming 公式。
  1. 現有 `nxt_state` 優先序維持：`clear > absorb > theta_lane_active > chi_lane_active`。
  2. 這層 mux 出來的 1600-bit 先當 `data_nxt` 進 `keccak_lane_ecc`；ecc 的 `data_wr` 再進 `keccak_state_bank`。
  3. `any_uncorr` + `theta_lane_active`/`chi_lane_active` 組成 `ft_src`，接 `keccak_ft_region` → scheduler 的 `fault_valid` / `replay_kind`。
  4. `theta_replay`/`chi_replay` 接回 θ/χ。`state_active_mask` 仍只跟 θ/χ/absorb/clear 的 `lane_active`；replay 那拍模組自己會再拉同一組 5 bit，不要另開寫入路徑。
  5. 注入 port：建議 top 加

```text
input logic        ft_inject_valid   // 正式合成綁 0
input logic [4:0]  ft_inject_lane    // 0..24
input logic [71:0] ft_inject_mask
```

TESTBED 有注入時才驅動。沒有這些 port 時不准在 RTL 裡藏 force。
* **注意：** ι 已在 χ 內，top 不要再分接 `iota_state`。`sleep_en = ~state_active_mask` 不變。UNCORR 若選擇「不寫」，該拍 mask 仍可為 1（clock 跳了但 data_wr=cur）或把該 lane 從 mask 拿掉——和 Phase 2 合約一致即可，兩人不要各做一半。

* **`00_TESTBED/PATTERN_FT.sv`（新檔）**  
  不要把注入塞進原本 `PATTERN.sv`。原 PATTERN 繼續當無 fault 回歸。
* **注入規則（寫死在檔頭）：**
  1. 只在 `lane_active[i]==1` 的當拍，對該 lane 的 **72-bit codeword** XOR `inject_mask`。
  2. 同一輪 Keccak-f 最多注入 1 次。
  3. 至少覆蓋：θ col0、θ col3、χ row0（含 ι）、χ row3、last round last χ；各一組 **1-bit**、再加一組 **2-bit**。
  4. 紀錄：`status`、`syndrome` 是否指對位置、`extra_cycles`、最終 hash。
* **1-bit：** extra cycle 必須為 0，hash 對，scheduler 看不到 `fault_valid`。  
* **2-bit：** `UNCORR` → replay，hash 對；χ 約 +1 cycle，θ COL +1，FROM0 最多 +5。

* **`00_TESTBED/filelist.f`：** 加入 `keccak_hamming64.sv`、`keccak_lane_ecc.sv`、`keccak_ft_region.sv`。`tb_hamming64.sv` 不要進這個 filelist。  
* **`syn.tcl`：** Person A 加同樣三個 RTL；注入 port 合成時接到常數 0。

`sha3_pad_domain.sv`、`sha3_absorb_xor.sv`、`sha3_output_formatter.sv`、`sha3_ctrl_fsm.sv`：**不改**。

**Phase 4 結束：**

1. 無注入：原 PATTERN 全過，keccak-f 仍 240 cycle。
2. 1-bit 五個注入點：修掉、Δ=0、hash 對。
3. 2-bit：replay 範圍符合 region 表、不重鎖 frozen、hash 對。
4. 一拍最多仍只有 5 個 `lane_clk`。

能量若要對無保護版，用 GitHub 上壓完效能的那個 commit 與加 FT 後的 `src/` 各跑一次現有 `sweep_dc.sh`（同一 `BLOCK_SIZE_BITS=1088`、同一 period）。比的是同一顆核心加了 25×8 校驗與 5 路編解碼的 overhead。本文件不排報告文案，也不在 repo 裡放第二份 RTL。

---

## 紅線（實作時）

- 不破 Candidate 3：一拍最多 5 個 lane clock（replay 那拍也是同一 row/col 的 5 個）。
- 不新增大扇出 AND-clock、不開 `compile_ultra -gate_clock`。
- 1-bit 不准進 replay；2-bit 不准依 syndrome 亂翻。
- χ replay 不准重鎖 `frozen_state`。
- 主方案不是再算一次 θ/χ 來當 detection。
- 兩人不同時改同一檔；port 意義只在 Phase 1 改。
- 不做五步 TMR、不做 χ 兩列同一拍、不對 20 個睡著 lane 每拍跑 Hamming 樹。

若 FROM0 在接線上卡住：允許先只保證 `THETA_COL` + `THETA_CD` + `CHI_ROW`，FROM0 暫時走 `THETA_CD` 再從頭 UPDATE；但 **不要** 因此把 1-bit 送去 replay，也不要再開三種 FT_MODE。
