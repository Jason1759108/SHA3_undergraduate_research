# Fault Detection / Recovery 論文導讀與算法講義

給 **兩個人一起讀**。這份不排寫 RTL 的工時（那份在 `fault detection and recover分工說明.md`），只回答：

1. 該看哪些論文、什麼時候看、每篇要學到什麼  
2. 還有哪些非論文材料能幫你們把算法搞懂  
3. 把之後會用到的每個算法從零講一遍  
4. **舊文獻怎麼偵測 / 怎麼修**，和 **我們準備做的差在哪**（越細越好）

預設讀者：**完全沒寫過 ECC、TMR、RERO**，但已經知道我們的 Keccak 一 round 是 10 拍、每拍最多更新 5 個 lane、有 `lane_active[24:0]`。

建議節奏（只讀書、不趕實作）：**兩週讀完必讀 + 講義例題**，比硬塞進四周實作週鬆很多。兩人每天同一篇、同一份筆記，不要分工讀不同論文。

---

## 第一部分：兩人共同閱讀清單與時程

### 1.1 怎麼讀才不會爆炸

每篇論文 **不要從 Introduction 逐字看到實驗圖**。固定只挖五件事，寫進 `others/ft_reading_notes.md`（一人一段也行，但定義必須共用）：

| 筆記欄 | 寫什麼（用自己的話，禁止貼摘要） |
| --- | --- |
| 它保護的對象 | 整顆 1600-bit？某一個 register？某一個 step？ |
| Detection 怎麼做 | 比什麼和什麼？何時比？ |
| 發現錯之後怎麼辦 | 只拉 error、翻 bit 修正、整段重算、投票？ |
| 粒度 | 一次保護 / 一次修復涵蓋多少 bit、多少 cycle |
| 對我們有用的一句 | 「我們要抄精神 / 當對照 / 當反例」哪一句 |

看不懂公式就先看這份講義對應章節，再回論文對名詞。

### 1.2 兩週讀書日曆（兩人同一天同一篇）

| 日 | 必讀 | 建議用時 | 讀完當天要能口述 |
| --- | --- | --- | --- |
| **D1** | 本講義 §3.1–3.4（fault / 奇偶 / Hamming） | 3–4 h | 奇偶能抓幾 bit？Hamming 的 syndrome 是什麼？ |
| **D2** | 本講義 §3.5–3.7（TMR、時間冗餘、RERO 精神）+ 講義 §4 | 3 h | TMR 和「再算一次」差在空間 vs 時間 |
| **D3** | FIPS 202 只複習 θ、χ 公式（你們已經會）+ 講義 §5（Keccak 幾何與 dependency） | 2 h | 為什麼 χ 是 1 row、θ 可能 1～3 col |
| **D4** | Torres-Alvarado et al., **Sensors 2022** ArchHC / ArchTMR-HC | 3–4 h | 5 個 1600-bit register + Hamming；TMR 加在五步上 |
| **D5** | Bayat-Sarmadi et al., **IEEE TCAD 2014** RERO | 3 h | 旋轉輸入再算一次，比的是整次結果 |
| **D6** | Ewert et al., **2025** arXiv:2512.03616 c-plane / z-sheet | 3–4 h | 用 column / lane / sheet 的 parity 做 register 偵測 |
| **D7** | Mestiri & Barraj, **Micromachines 2023** | 2 h | 高 detection、不修，當「只偵測家族」 |
| **D8（選讀）** | Gavrilan et al., **TCHES 2024** Impeccable Keccak | 2 h | 強韌性、約 3× 面積，知道就好 |
| **D9** | 本講義 §6–7 + 10-cycle 表 | 3 h | 能手算 (7,4) 一例，並口述 64-bit lane 1-bit 翻 / 2-bit replay |
| **D10** | 兩人互相考：舊方法 vs 我們（§8 對照表） | 2 h | 講得出「為什麼不能拿 ArchHC 的 Mbps 比 energy/bit」 |

論文 PDF 來源（瀏覽器開，不必全印）：

- ArchHC：MDPI Sensors 2022, *An SHA-3 Hardware Architecture against Failures Based on Hamming Codes and Triple Modular Redundancy*（PMC 也有）
- RERO：IEEE TCAD 2014, *Efficient and Concurrent Reliable Realization of the Secure Cryptographic SHA-3 Algorithm*（作者頁常有 PDF）
- Ewert 2025：arXiv:2512.03616
- Mestiri 2023：Micromachines，PMC 全文
- Impeccable Keccak：IACR TCHES 2024 / ResearchGate

### 1.3 每篇論文「應該學到什麼」（不是學他們的 FPGA 數字）

#### Torres-Alvarado 2022 — ArchHC / ArchTMR-HC

**定位：你們 related work 裡「真的有做硬體修正」的代表作。**

要學到：

1. **保護單位是 1600-bit 的 central register**，不是 lane。他們假設 Keccak 中間有幾份完整 state，每份掛 Hamming。
2. Hamming 的能力：每個 register **偵測並修正 1-bit**（論文口径）。24 round × 5 register → 他們寫 **120 errors / KECCAK-p**。這是「最壞情況每個 register 每 round 各中 1 bit 都還修得回來」的行銷式 coverage，**不是** energy 公式。
3. ArchTMR-HC：五個 step（θρπχι）再各做一份 TMR，voter 多數決。Coverage 寫成 10×24=240。代價是面積與功耗。
4. **對設計的幫助：** 對照組 FT_STATE1600 的精神從這裡來——「錯了就修 / 遮住 **整包 state 或整步**」。  
   **不要學：** 把五步各做三份；那是和 Candidate 3 相反的路。

#### Bayat-Sarmadi 2014 — RERO

**定位：「不要複製硬體，用時間再算一次來抓錯」。**

要學到：

1. RERO = Recomputing with Rotated Operands：先算 \(F(x)\)，再算 \(F(R(x))\)，把第二次結果轉回來和第一次比。不同 → 有 fault。
2. 它主要是 **Detection**。論文強調面積可以很小（約數 %），吞吐會掉，因為多做了工作。
3. **對設計的幫助：** 當 Hamming 說 2-bit 不能翻時，才用「再算一小段」當備援。RERO 的整段再算只當能量上限對照。
4. **不要學：** 把輸入整包旋轉再跑完整 24 round 當主方案。

#### Ewert 2025 — c-plane / z-sheet

**定位：最接近「利用 Keccak 立方體幾何做細粒度偵測」的新論文。**

要學到：

1. Keccak state 是 \(5\times5\times64\)。他們沿不同切面做 parity：column 面（c-plane）、lane 方向再組 z-sheet。
2. 宣稱可 **100% 抓到 ≤3 bit flip**（z-sheet），overhead 約數十 %，仍是 **register-level detect**。
3. 作者把文獻分成 detection / correction，並指出 **很少人做 register 修正**。這句話可以直接進你們 introduction。
4. **對設計的幫助：** 解釋「為什麼可以只對一部分 bit 做檢查」；若 FT_STATE1600 先做 column parity，related work 可以寫「detect 幾何類似 Ewert，recover 走我們的 lane-serial replay」。
5. **不要學：** 以為有了 z-sheet 就等於會修。他們偵到就發 error，不重算某一 row。

#### Mestiri & Barraj 2023

**定位：低成本、高覆蓋、只偵測。**

要學到：scrambling + 管線化 round 讓 fault 容易在輸出被看見；single-bit 100% detect。用來填「detect-only 家族」。不抄他們的 scrambling 當主架構。

#### Gavrilan 2024 Impeccable Keccak（選讀）

**定位：編碼 + checkpoint，極高韌性，面積約 3×。** 學到「可以把 Keccak 做成幾乎不容錯碼」，以及這不是低功耗 lane-serial 該走的成本。讀完 Introduction + 結論即可。

### 1.4 論文以外、兩人一起看的學習資源

這些比論文更適合「從零學會算法」，論文反而常假設你已會 Hamming。

| 資源 | 看哪一段 | 對應講義 |
| --- | --- | --- |
| 任何「Parity bit / even parity」一頁講義 | 偶校驗如何抓 1 bit、抓不到 2 bit | §3.2 |
| Wikipedia 或教材 *Hamming code (7,4)* | 資料 4 bit、校驗 3 bit、syndrome 指出哪一 bit | §3.3 |
| *SECDED / Hamming 擴充一位* | 多 1 bit 區分 1-bit 可修 vs 2-bit 只偵測 | §3.3 |
| TMR 一頁圖（三模組 + voter） | 空間換正確 | §3.5 |
| FIPS 202 §3.2.1–3.2.5 只看 θ、χ 公式 | 你們已會，D3 對著 RTL 再看一次 | §5 |
| 本 repo `keccak_theta_serial.sv` / `keccak_chi_row.sv` 的 10-cycle 註解 | 算法要掛在真實拍上 | §5.3 |

不需要先修編碼理論課，但 **主方案已經改成每個 lane 一顆 Hamming SECDED**。Parity 用來理解「1 顆校驗只能抓奇數個錯、不能指出位置」；Hamming 是把校驗加到 7+1 顆，才能指出並翻 1 bit。RERO / 再算一次只當 2-bit 備援。

---

## 第二部分：從零講「錯了是什麼、抓錯、修好」

### 2.1 硬體 fault 在這份專題裡是什麼

想像 `cur_state` 裡某一個 64-bit lane，某一拍寫入時，**其中 1 個 FF 因為粒子擊中、電壓毛刺、或模擬裡我們故意 XOR 1**，存進錯誤值。

- **暫態（transient）：** 只這一次寫錯，電路之後還是好的。再算一次同一條公式，通常會得到對的值。  
  → 我們第一版 **只處理這個**。
- **永久（permanent）：** XOR 閘壞了，再算一百次都錯。  
  → 重算救不了，要 TMR 或換備援硬體。第一版不做，報告寫未來工作。

所以：**Detection = syndrome 不是 0。Correction = 1-bit 時依 syndrome 翻那一 bit。Recovery 備援 = 2-bit 解不開時才重算該 row/col。**

### 2.2 三個詞必須分開（口試最常被混）

```text
Detection     知道「有錯」
Localization  知道「錯在哪一個 lane / 哪一 row / 哪一 col」
Correction    不重算，直接把錯的 bit 翻回來（Hamming、voter）
Recovery      較廣：包含 correction，也包含「重算再寫」
```

ArchHC 的主路徑是 **Correction**（解 Hamming，翻 bit）。  
RERO / Ewert / Mestiri 主路徑是 **Detection**（拉旗號）。  
我們主路徑是 **Detection + Localization + Hamming Correction（翻 1 bit）**；replay 只處理 SECDED 判成 2-bit 的情況。

---

## 第三部分：舊世界會用到的算法（一個一個講）

以下算法 **文獻在用**。我們主方案只「借用精神」，實作見第六、七部分。

### 3.1 冗餘的兩種買法：空間 vs 時間

要發現「算錯了」，你手裡必須有 **兩個版本的答案** 才能比。第二份答案從哪來：

| 買法 | 做法 | 多付的成本 | 典型文獻 |
| --- | --- | --- | --- |
| **空間冗餘** | 同一拍用兩份或三份電路 | 面積、漏電、時脈負載 | TMR、ArchTMR、Hamming 的校驗位也是空間 |
| **時間冗餘** | 同一份電路再跑一次 | 多 cycle、吞吐下降 | RERO、我們的 replay |

我們 Candidate 3 已經用時間把 1600-bit 折成 10 拍。再在「出錯的那一小段」加一點時間，比再複製 1600-bit 寄存器符合低功耗故事。

### 3.2 奇偶校驗（Parity）— 最便宜的 Detection

**定義：** 對一串 bit 做 XOR，得到 1 bit。

- Even parity：資料裡 1 的個數為偶數時，parity=0；奇數則 parity=1。也就是  
  \(p = b_0\oplus b_1\oplus\cdots\oplus b_{63}\)。
- 存資料時把 \(p\) 一起存。讀出來再算一次 \(p'\)，若 \(p'\neq p\) → **有奇數個 bit 錯了**。

**能力：**

- 1 bit 錯：一定抓到。  
- 2 bit 錯：兩個 1 互相抵消，**抓不到**。  
- 知道「這 64 bit 裡有事」，**不知道是哪一 bit**。

**例：** 資料 `110`，even parity \(1\oplus1\oplus0=0\)。存成 `110|0`。若變成 `100|0`，新 XOR=1 ≠ 0 → 偵測到。

這就是「檢查和」的最小版。Ewert 的 c-plane 本質是：**很多組 parity，每組對一條 column / 一個切面**，所以能多知道「錯在哪一個切面」，仍然多半 **不能自動翻回那一 bit**（除非再加 Hamming）。

### 3.3 Hamming Code — ArchHC 在幹嘛

把 parity 從 1 bit 加到 **好幾 bit**，讓「哪幾顆 parity 不對」編成一個數字，這個數字叫 **syndrome（症候群）**，可以直接指向「第幾 bit 錯了」，然後把它翻回來。這叫 **SEC（Single Error Correction）**。

課堂經典是 **(7,4)**：4 個資料 bit，3 個 parity，共 7 bit。

編號 1–7（從 1 開始，方便對二進位）：

| 位置 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 角色 | P1 | P2 | D1 | P4 | D2 | D3 | D4 |

- P1 管所有位置編號二進位含 `001` 的：1,3,5,7  
- P2 管含 `010` 的：2,3,6,7  
- P4 管含 `100` 的：4,5,6,7  

寫入時算出 P1,P2,P4 使各組 even。讀出時重算三組，得到 3-bit syndrome。  
Syndrome=`000` → 沒出錯。  
Syndrome=`101`（=5）→ 第 5 個位置錯了，把那 bit 取反。

**SECDED：** 再加 1 個涵蓋全體的 parity。  
- 1 bit 錯：能指出位置並修正。  
- 2 bit 錯：能發現「有兩 bit 錯」但 **修正會指錯人**，所以只偵測、不亂翻。

**64-bit lane 若做 Hamming：** 大約再加 7～8 個校驗位（(72,64) 一類）。  
**1600-bit 整包若做 Hamming：** 校驗位大約 11～12 bit，但組合邏輯樹極寬，這就是 ArchHC 面積大、我們 DC 也會痛的原因。

**ArchHC 的運作（舊方法，detection + correction）：**

```text
1600-bit state register
    ├── 寫入時：算 Hamming parity，和 1600 bit 存在一起
    ├── 讀出時：算 syndrome
    │       ├── 0        → 當沒有錯
    │       ├── 指向第 k → 把第 k bit 翻掉（correction）
    │       └── 多 bit    → 視 SEC/SECDED 規格，可能只 detect
    └── 後面的 θ/χ 用「修過的」state 繼續算
```

它 **不需要知道是哪一個 lane 正在算**。整包隨時可修 1 bit。也不需要 `lane_active`。

### 3.4 為什麼「能修 1 bit」仍可能能量很差

Hamming 的校驗樹 **每個 cycle 都掛在 1600-bit 上**（或每個 central register 上都掛）。我們的 state 大部分時間有 20 個 lane 在睡覺，但 1600-bit Hamming 不管誰 active，校驗樹仍在。DC 沒有 SAIF 時尤其會把這棵樹算進 dynamic power。這是後面談「不要把主方案做成 ArchHC」的工程理由。

### 3.5 TMR（Triple Modular Redundancy）— ArchTMR 在幹嘛

**定義：** 同一份組合邏輯做 **三份**，輸出做 **多數決（voter）**。

```text
x ──► F1 ──┐
x ──► F2 ──┼── majority(F1,F2,F3) ──► 認為是正確答案
x ──► F3 ──┘
```

- 一份算錯、兩份對：voter 輸出對的。這是 **masking**（錯被蓋掉），常常 **連 error flag 都沒有**。  
- 兩份同時錯：修不了。  
- 代價：約 3× 組合邏輯 + voter。ArchTMR-HC 對 θ、ρ、π、χ、ι 各做這種事。

和 Hamming 的差別：Hamming 是 **存在 register 裡的編碼**；TMR 是 **運算當下的三倍電路**。都屬於空間冗餘。

我們 **不做** 五步 TMR。

### 3.6 時間冗餘：同一份電路再跑一次

**定義：** 不複製 F，把同一組閘用 **第二個 cycle** 再算一遍，兩次結果相減（XOR）。非 0 → 有錯。

```text
Cycle T  :  out1 = F(x)     寫進暫存
Cycle T+1:  out2 = F(x)     若 out2 != out1 → fault
```

- 暫態 fault 只 concide 一次時，第二次常是對的 → 既可 detect，也可拿 out2 當 recovery。  
- 若 F 永久壞掉，兩次都錯且可能相同 → 抓不到。  
- 吞吐：那段運算的時間 ×2。

RERO 是時間冗餘的「聰明版」：第二次不是 \(F(x)\) 而是 \(F(\mathrm{Rotate}(x))\)，再把輸出轉回來。好處是某些 **永久的位元錯誤或固定接線錯誤** 比較容易和第一次不一樣，detection 較強。代價仍是 **整次運算級** 的雙倍工作。

### 3.7 RERO 逐步（舊方法，幾乎只有 Detection）

1. 正常算 SHA-3 / Keccak：得到摘要或中間 state \(Y=F(X)\)。  
2. 把輸入 bit 做固定旋轉（或 lane 內旋轉）得 \(X_R=\mathrm{Rot}(X)\)。  
3. 再跑同一硬體 \(Y_R=F(X_R)\)。  
4. \(\mathrm{Rot}^{-1}(Y_R)\) 應等於 \(Y\)。不等 → 宣告 fault。  

**沒有**「只重算 row 2」。Localization 通常只到「這次雜湊壞了」。  
Recovery 若要做，往往是 **整次再來**（再付一次時間）。

---

## 第四部分：Keccak 裡和 fault 有關的幾何（只講會用到的）

State 是立方體：\(x=0..4\)（column）、\(y=0..4\)（row）、\(z=0..63\)（lane 裡的 bit）。  
我們硬體的 **一個 lane** = 固定 \((x,y)\) 的 64 個 \(z\)。

`lane_active[y*5+x]=1` 表示這一拍這個 lane 的 clock 會跳、會寫入。

### 4.1 χ：錯了為什麼可以只重算 1 row

同一 \(y\)、不同 \(x\) 的五個 lane 互算：

\[
B[x,y,z]=A[x,y,z]\oplus\big(\neg A[x+1,y,z]\land A[x+2,y,z]\big)
\]

**不看其他 row。** 所以：

- Detection：這一拍 `lane_active` 本來就是 row \(y\) 的 5 個 lane，檢查這 5 個就夠。  
- Recovery：用 **同一份輸入**（row0 用當拍 `in_state`；row1–4 用 `frozen_state`）把這 row 的 χ **再組合一次**，再開這 5 個 lane clock 寫回去。  
- row0 還要 XOR `RC[round]`（ι）。重算時 `round_index` 不准變。

Pi 會把資料跨 row 搬動，所以我們才有 `frozen_state`。Recovery **必須繼續讀凍結值**，不能 `start` 再拍一次把已經被 χ 寫過的 state 凍進去。

### 4.2 θ：為什麼舊一句「重算 1 column」不夠

θ 分兩層：

\[
C[x]=\bigoplus_{y=0}^{4}A[x,y]
\qquad
D[x]=C[x-1]\oplus\mathrm{ROT}(C[x+1],1)
\qquad
A'[x,y]=A[x,y]\oplus D[x]
\]

現在 RTL：

- Cycle 1：用 **更新前** 的整包 state 算完全部 \(C\)、\(D\)；寫 col0（\(A'[0,y]=A[0,y]\oplus D[0]\)）；posedge 只鎖 \(D[1..4]\)。  
- Cycle 2–5：\(A'[c,y]=A[c,y]\oplus D[c]\)，這裡的 \(A\) 仍是 **θ 開始前** 的值（別欄還沒寫，或寫的是別欄）。

所以 dependency 要分「算 D 的錯」和「寫欄的錯」：

```text
C[0] 依賴 column 0 的五個舊 lane
D[1] 依賴 C[0] 和 C[2]
寫 column 1 只依賴「舊 column 1」和 D[1]
```

若 **D[1] 是對的**、只有寫入 XOR 或 FF 翻了 → 重做 `舊col1 XOR D[1]` 即可（1 column）。  
若 **C/D 算錯** → D[1]～D[4] 都可能毒掉 → 必須重算 C/D，必要時從 col0 重寫。

這不是為了把題目變難，是為了口試被問「你憑什麼只重算一欄」時有圖。

### 4.3 ρ/π 與 ι

- ρ/π：純 wiring，0 cycle。Fault 若發生在這段 wire，會反映在 χ 的輸入上；我們第一版把「可重播的運算」放在 θ 寫欄與 χ 寫列。  
- ι：只打 `lane(0,0)`，已併進 χ cycle 6。Detection / recovery 把 ι 算進 row0 的期望值即可。

---

## 第五部分：舊文獻整條流水線（Detection 與 Recovery 分開）

### 5.1 舊 Detection 怎麼做

| 方法 | 比什麼 | 何時比 | 看到的範圍 |
| --- | --- | --- | --- |
| **Parity / Ewert 切面** | 切面上的 XOR 和存起來的校驗 | 讀 state 或每 round 邊界 | 某切面有奇數（或 ≤3）bit 錯 |
| **Hamming / ArchHC** | syndrome 是否為 0 | 每次從 central register 讀出 | 整個 1600-bit 裡哪 1 bit（SEC） |
| **TMR voter** | 三份輸出是否一致 | 該 step 的組合邏輯算完 | 常常只輸出「投票結果」，不一定告訴你誰錯 |
| **RERO** | \(Y\) vs \(\mathrm{Rot}^{-1}(F(\mathrm{Rot}(X)))\) | 整段運算結束 | 「這次運算壞了」 |
| **Mestiri 類** | 打亂 / 管線後的預測與實際 | round 內檢查點 | 高機率有錯，粒度仍偏整步 |

共同點：**檢查範圍事先固定成「整個 register」或「整個 F」**，不管這一拍實際上只改了 5 個 lane。

### 5.2 舊 Recovery / Correction 怎麼做

| 方法 | 發現錯之後 | 再開多少運算 | 寫回多少 state |
| --- | --- | --- | --- |
| **ArchHC Hamming** | syndrome 翻 1 bit | **0** 次 Keccak 運算（只做解碼） | 理論上 1 bit，控制仍繞 1600-bit 寄存器 |
| **ArchTMR** | voter 輸出多數 | 0（三份已經算完） | 整步的輸出 |
| **RERO 若要恢復** | 通常再跑一次完整 F 或丟棄重來 | 約 **整次** 時間 | 整包 |
| **Ewert / Mestiri** | 拉 error，上層 abort 或重送 | 由系統決定，核心不管 | 核心不管 |
| **「整 round 重跑」（我們對照組會做的舊精神）** | 從本 round cycle 1 再來 | +10 cycle | 本 round 寫過的欄/列再寫一遍 |

舊 correction 的優點：Hamming / TMR **當拍就能出正確值**，不必排程器回頭。  
舊 correction 的缺點：校驗或三倍電路 **一直開著**；granularity 粗。

---

## 第六部分：我們準備做的 Detection / Correction（lane Hamming）

主路徑：**每個 64-bit lane 一顆 (72,64) SECDED**。寫入時 encode，讀出或寫完時 decode。`lane_active=0` 的 20 條 **不跑** 72-bit 編解碼樹（operand isolation）。校驗 8 bit 跟著該 lane 的 `lane_clk` 存。

紙上算法與 (7,4) 手算見本講義 §3.2–3.3；對 64-bit 只是把 parity 位從 P1,P2,P4 加到 P1…P64（位置 1,2,4,8,16,32,64）。

### 6.1 模組角色

```text
θ/χ 算出 64-bit data
    → encode（只對 active lane）→ 72-bit code 寫進 {data_ff, ecc_ff}
    → decode
         ├── status=OK              沒事
         ├── status=CORRECTED_1BIT  data 翻 1 bit 後當正確值用（主路徑）
         └── status=UNCORR_2BIT     才 fault_valid → replay
```

### 6.2 逐步：χ row2、lane 的 data bit 7 被翻（1-bit，主路徑）

1. χ 算出正確 64-bit，encode 出正確 8 個校驗。  
2. 注入翻了 data bit 7，codeword 裡剛好 1 bit 錯。  
3. decode：syndrome 指向該資料位，全體 parity 不對 → 判定 1-bit。  
4. 把 bit 7 取反，得到原資料。**不必** replay、`cnt` 照常加。  
5. 另外 4 個 lane syndrome=0。睡著的 20 個不 decode。

### 6.3 2-bit：同一 lane 兩個 data bit 被翻

syndrome ≠ 0，但全體 parity 仍對（兩次 extra-parity 互消）→ **UNCORR**。此時 Hamming **不准翻**（翻會變成第三個錯的字）。才走 χ 重算該 row。

### 6.4 和舊方法差在哪

| 項目 | ArchHC | Ewert parity | RERO | **我們** |
| --- | --- | --- | --- | --- |
| 碼長 | 1600+約 11 | 切面 1 bit 組 | 無碼 | **64+8，×25 條，一拍只用 5 條** |
| 1-bit | 翻 | 只知道切面 | 整段再比 | 翻，0 extra keccak cycle |
| 2-bit | SECDED 則只偵測 | 視設計 | 視旋轉 | 只偵測 → **局部 replay** |
| `lane_active` | 不用 | 不用 | 不用 | **關掉 20 條編解碼樹** |

**限制：** 沒在寫的 lane 若 retention 被打到，當拍不 decode 就看不見。可列未來工作（偶爾掃 25 條）。閘算錯、資料「合理地錯」時 Hamming 會認為碼對——修不了組合邏輯錯，2-bit replay 也修不了永久閘錯。

---

## 第七部分：我們準備做的 Recovery

分兩層，不要混：

1. **1-bit：Hamming correction**（主路徑，不算「重算」）。  
2. **2-bit：selective replay**（備援，和舊講義一樣：χ 1 row，θ 看 D 是否可信）。

### 7.1 為什麼還要留 replay

Hamming SECDED **修不了 2-bit**。此時資料已不可信，但 θ 的 `D[]`、χ 的 `frozen_state` 往往還在。再跑同一拍公式，用新算出的 64-bit **重新 encode** 寫回去。同一處最多 replay 1 次。

### 7.2 時序（建議：下一拍才 replay）

```text
Cycle T  : 本體算完、checker 比完、fault_valid=1
           注意：若同拍已經寫進 FF，state 裡已經是錯的
Cycle T+1: replay=1，index 不變，再算、再開同一組 lane_clk，覆寫
Cycle T+2: 若比較通過，index 才前進（或 T+1 覆寫後繼續原進度）
```

1-bit 的 Δ 目標是 **0**。只有 `UNCORR` 才走這段，Δ 至少 +1。

若同拍寫入前就能擋（`nxt_state` 用 expect 蓋掉），Δ 可以是 0，但要改 top mux，較容易和 gating 打架。第一版用 **寫錯再覆寫** 比較好做。

### 7.3 χ Recovery 逐步（row 2）

1. `fault_src=CHI`，`cnt` 仍是 2。  
2. Scheduler 發 `chi_replay=1` **一拍**。  
3. χ：**禁止** `if (start) frozen<=in_state`。`cnt` 保持 2。  
4. 再算 row2，`lane_active` 再拉 row2。  
5. State bank 五個 lane 再被 clock，覆寫正確值。  
6. 下一拍 `cnt=3`，round 繼續。  
7. `round_index` 不變；ι 只在 row0 才會再 XOR。

**重算範圍：1 row = 5 lanes = 320 bit 的組合 + 5 個 FF 的 clock。**  
對照 ArchHC：解 1600-bit Hamming。  
對照整 round 重跑：+10 cycle vs +1～2。

### 7.4 θ Recovery 逐步（三種）

**A. `FT_REPLAY_THETA_COL`（D 可信，例如 cycle 4 只有 1 個 lane mismatch）**

1. `col` 保持 3。  
2. `out = in XOR D[3]` 再做一次。  
3. 只開 col3 的 5 個 clock。  
4. 然後 `col` 才加到 4。

**B. `FT_REPLAY_THETA_CD`（cycle 1，C/D 或整欄 5 個都 mismatch）**

1. 行為等同再做一次 start 拍：`compute_d` 再打開，重算 `C_comb`/`D_comb`，重寫 col0，重鎖 `D[1:4]`。  
2. 之後 cycle 2–5 用新的 D。若 col1 已經寫過錯的 D，需要 **C**。

**C. `FT_REPLAY_THETA_FROM0`（已經寫了 col1–k，後來才發現 D 是毒的）**

1. 重算 C/D。  
2. 從 col0 重寫到 col4（最多再 5 拍，加上已經過的）。  
3. 這是 θ 的 worst-case，報告單獨一欄。W2 若來不及，允許退化成「整段 θ 重跑」（也是 +1～5），不要卡死專題。

### 7.5 我們的 Recovery 和舊方法差在哪（對照）

| 項目 | ArchHC 翻 bit | TMR vote | 整 round / 整 F 重跑 | **我們 replay** |
| --- | --- | --- | --- | --- |
| 要不要再跑 θ/χ 公式 | 不要 | 已經跑了三遍 | 要，而且是整段 | **只要跑錯的那 1 拍公式** |
| 打開多少 lane clock | 視實作，常動到整包 register | 整步輸出 | 該段所有曾寫過的 lane | **同一組 5 個 active** |
| 依賴 `frozen` / `D[]` | 不需要這些快取也能修 1 bit | 不需要 | 需要從頭的輸入 | **強依賴現有快取**（這是 lane-serial 才漂亮的原因） |
| 1-bit 寫入錯誤 | 修那 1 bit | 被另外兩份蓋掉 | 能好，但太貴 | **同樣翻 1 bit，但碼只有 72 寬、且只解 5 條** |
| 永久閘錯誤 | Hamming 救不了組合邏輯錯 | 一份壞掉仍可能好 | 仍會錯 | **救不了**（要講出來） |
| 無 fault 時 | 校驗樹一直在 | 三倍邏輯一直在 | 沒有 replay 就不跑 | checker 仍在（小）；replay 邏輯閒置 |

「整 lane 重寫」比 Hamming 「只翻 1 bit」粗一點，但控制簡單，且 5 個 lane 本來就要一起 clock。Energy 主場在 **少做的 cycle 與少開的 Hamming 樹**，不在「少翻 63 個正確 bit」。

### 7.6 和 RERO 的一句話差別

```text
RERO:     F(x) 然後 F(Rot(x))     → 範圍 = 整個密碼運算
我們:     F_row(y) 或 F_col(x) 再做一次 → 範圍 = 本拍 serial 單元
```

都是 recomputation；我們是 **spatially selective recomputation**。

---

## 第八部分：一張總表（舊實現 vs 我們要做的）

### 8.1 Detection

|  | 舊：ArchHC | 舊：Ewert | 舊：RERO | **新：lane-aware** |
| --- | --- | --- | --- | --- |
| 算法名 | Hamming SEC on 1600-bit | 切面 parity | 旋轉再算完整 F | **每 lane (72,64) SECDED** |
| 輸入 | 整包 state | 整包 state | 整包訊息 / state | `lane_active` + 5 個 72-bit code |
| 輸出 | syndrome / 修正值 | error（切面） | pass/fail | 每 lane 的 status + 修正 data |
| 閒置 lane | 仍編碼 | 仍進切面 | 含在 F 裡 | **忽略** |

### 8.2 Recovery

|  | 舊：ArchHC | 舊：TMR | 舊：重跑 F 或 round | **新：dependency replay** |
| --- | --- | --- | --- | --- |
| 算法名 | Decode and flip（1600） | Majority vote | Time redundancy (full) | **Decode and flip（64）+ 2-bit replay** |
| 控制 | 大解碼器 | voter | 大 FSM 從頭 | 5 個小解碼器；UNCORR 才不前進 `col`/`cnt` |
| χ / θ 1-bit | 翻 1 bit | 投票 | 整段 | **翻 1 bit，0 extra cycle** |
| 2-bit | 只偵測 | 視幾份錯 | 整段 | **1 row / 1～3 col replay** |
| 多付 cycle（1-bit transient） | 0 | 0 | +10 或 +240 | **0** |

---

## 第九部分：用一個完整故事把兩段串起來

場景：第 7 個 round、χ cycle 8、row 2、lane (1,2) bit 0 被打翻。電路其餘正常。

**舊 ArchHC 會發生的事：**  
寫入後 1600-bit register 的 Hamming syndrome ≠ 0，指向那 1 bit，翻回來。θ/χ FSM 無感。你們付的是 **持續的 1600-bit 編解碼功耗**。

**舊 RERO 會發生的事：**  
這一 round 甚至整次 hash 結束才發現 \(Y\) 對不上，再跑一次完整運算。付 **大量 cycle**。

**我們要發生的事（1-bit）：**

1. 該 lane 的 72-bit decode，syndrome 指向 bit 0。  
2. 翻 bit 0，θ/χ FSM 無感，**不多 cycle**。  
3. 量測：status=CORRECTED、digest 對、Δ=0。

若是 **2-bit**：status=UNCORR → 才 `chi_replay` 該 row（frozen 不變），Δ=+1～2。

把這個故事講順，論文 introduction 就立得住。

---

## 第十部分：讀完講義的自測（兩人互問）

1. 奇偶抓得到 2-bit 錯嗎？Hamming SEC 呢？SECDED 呢？  
2. Syndrome=`101` 在 (7,4) 代表什麼？要翻哪一顆？  
3. 為什麼 1-bit 不准進 replay、2-bit 不准用 syndrome 亂翻？  
4. 為什麼 replay χ 時不能再執行 `if (start) frozen<=in_state`？  
5. 我們的碼和 ArchHC 都是 Hamming，差在哪一句（64×5 vs 1600）？  
6. 休眠中的 lane 被打到，當拍為什麼可能沒看到？

答得出這六題，就可以開始照分工說明改 RTL；答不出就只重讀對應節，不必先開新模組。
