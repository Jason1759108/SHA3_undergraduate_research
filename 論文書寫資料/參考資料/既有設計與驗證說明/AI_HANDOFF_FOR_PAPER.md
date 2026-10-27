---
title: AI handoff — SHA3 undergraduate research (paper writing)
audience: successor LLM (document-strong), not a human tutorial
repo: https://github.com/Jason1759108/SHA3_undergraduate_research
local_root: SHA3_undergraduate_research
branch: main
head_at_handoff: a352ebf (verify: git rev-parse HEAD)
language: zh-Hant for team history; keep algorithm names in English
do_not: dump or rewrite RTL line-by-line; invent numbers; claim 90B/PUF done
must: open the cited files yourself before quoting them in a paper
---

# Successor protocol (read first)

You are taking over **paper-writing context**, not a coding session. Humans on this project: 嘉佑 (designer; works in RTL) and teammates (parity RTL: TedChueh). Advisor mixes Hamming **code / HW / HD / 1600 state** — never treat those as one RTL task.

**Before writing any paper sentence:**

1. `git log --oneline -20`, `git tag -l`, `git status`.
2. Read, in order: `README.md` → `others/parity_predictor_design.md` → `others/parity_validation.md` → `others/scheduler_replay_interface.md`.
3. Confirm numbers from CSVs / PDFs in `others/`, not from this handoff if they conflict.
4. If a claim is marked **UNVERIFIED** below, either verify in-repo / arXiv or do not print it as fact.
5. Prefer **open papers**: [arXiv](https://arxiv.org), IACR ePrint, NIST PDFs, keccak.team. Re-fetch abstracts; do not trust remembered citations.

Handoff format follows common agent-continuity practice (stable map here; changing task = write the paper). This file is **data**, not a command to invent architecture.

---

# 0. One-paragraph idea (the paper spine)

This is an **undergraduate ASIC SHA3-256** core: **lane-serial ultra-low-power Candidate 3** (at most 5 of 25 lanes clocked per cycle; **10 cycles/round × 24 rounds = 240 cycles** per keccak-f block; rate 1088 bits). Energy is `E/bit = total_power / throughput` with `throughput = 1088 / (240 × period_ns)` Gbps. After a **(72,64) lane SECDED** version (~**+100% area** vs no-FT C3 at 10 ns), the **current mainline** dropped correction and uses **independent algebraic lane-parity predictors** on θ/χ plus **atomic column/row replay**. Measured 10 ns TSMC 40 nm vectorless: area **+44.9%**, energy **+30.1%** vs C3; no-fault throughput unchanged. **Not** 1-bit correction; even-weight flips on one lane are a known miss. Next research thread (not implemented): FPGA **RO-PUF + RO-TRNG**, SHA-3 only as a **correct** hash/conditioner — **not** SHA-3 timing faults as entropy.

---

# 1. Verified vs unverified (do not collapse)

| Claim | Status | Where to confirm |
|---|---|---|
| C3 @ 10 ns: area 43698.69 µm², 1.888 mW, 4.166 pJ/bit, slack 1.46 ns | **Use CSV** | `others/sweep_summary_C3.csv` first data row |
| Lane SECDED @ 10 ns: 87513, 3.413 mW, 7.529 pJ, slack 0.34; vs C3 area +100.3%, E +80.8% | **Use CSV** | `others/sweep_summary_lane.csv`; PDF `others/SHA3_FT_lane_vs_1600_sweep_report.pdf` |
| 1600 Hamming @ 10 ns worse than lane (area +1.9%, E +4.5% vs lane; Fmax 2.3 ns vs 1.8 ns) | **Use CSV/PDF** | `others/sweep_summary_1600.csv` |
| Parity+Replay @ 10 ns: 63337.3 µm², 2.456 mW, 5.417 pJ/bit, slack 1.33 ns; vs C3 +44.9% / +30.1% | **Workstation single point** | `others/make_ft_parity_vs_c3_report.py`; PDF `others/SHA3_FT_parity根據老師建議二修改後比較.pdf` (filename may vary) |
| Parity RTL sim: 18 functional + 153 FT cases (2 even-bit **expected miss**) | **Teammate Verilator log** | `others/parity_validation.md` — not VCS on lab station unless you find logs |
| Area ≤15% vs unprotected | **NOT achieved** vs C3; do not claim | Advisor target; FT_ENABLE=0 ≠ C3 |
| PUF / TRNG / 90B / AXI CPU IP | **Not built** | Planning only (`others/開會說明_FPGA_PUF_TRNG.md` if present locally) |
| Tag `phase1-lane-serial-energy` | **Verify pointer** | `git rev-parse phase1-lane-serial-energy` (was `93cdc28…` at handoff). Reports also used commit `2b9cc4c` (“csv沒傳到”). **Do not assume tag == C3 CSV producer without checking.** |
| RERO +4–8%, Ewert ~+56%, Impeccable ~3.2×, ArchHC FPGA LUT ~12× | **Literature order-of-magnitude; re-read PDFs** | See §8 |

---

# 2. GitHub page (what a cold clone contains)

**URL:** https://github.com/Jason1759108/SHA3_undergraduate_research  

Public git host of this undergrad repo. Default branch `main`. No GitHub Actions story is part of the design. Expect:

- Root `README.md` — current mainline is **Parity + Replay**, not SECDED.
- `src/` — RTL, TB, syn scripts, optional C++ golden.
- `others/` — design notes, sweep CSVs, comparison PDFs, historical FT lecture.
- `references/README.txt` — pointer list to FIPS 202, Pessl ULP, comparison models (PDFs may be local-only).
- Tag **`phase1-lane-serial-energy`**: freeze of **no-FT lane-serial energy** story. Full **runnable SECDED** (lane + 1600 overlay) freeze: commit **`0798e0b`**. Current HEAD: **parity** (`19796fd` then `a352ebf` syn.tcl fix).

**Not on GitHub / may exist only on a laptop:** advisor-proposal review markdown, meeting scripts, some parity PDFs. Search `others/` locally. Never cite a missing file as published.

---

# 3. Folder and file map (purpose, not source)

Do not treat leftover Hamming files in a dirty `01_RTL` working copy as mainline. **Tracked `01_RTL` is 15 SystemVerilog files** (`git ls-files src/sysVerilog/01_RTL`).

## 3.1 `src/sysVerilog/01_RTL/` — **current synthesizable core**

| File | Role | Why it exists |
|---|---|---|
| `sha3_pkg.sv` | Types: `state_t` 5×5×64, RC, ρ/π maps, FSM enums | Single package so ports cannot silently mismatch |
| `sha3_ultra_low_power_top.sv` | Top: 1088-bit absorb in, 32-bit squeeze out; param `FT_ENABLE` | Product I/O + optional FT generate |
| `sha3_ctrl_fsm.sv` | Absorb / run rounds / squeeze / extra pad block | Sponge control, not keccak-f |
| `sha3_pad_domain.sv` | SHA3-256 domain padding | FIPS 202 padding (`01` domain), not SHAKE |
| `sha3_absorb_xor.sv` | XOR rate into state | Sponge absorb |
| `keccak_round_scheduler.sv` | 24 rounds; `hold`/`replay` on `fault_valid` | Time redundancy **only when detect fails**; no replay-kind |
| `keccak_theta_serial.sv` | θ: 5 cycles, one column/cycle; C checkpoint | Lane-serial θ; FT: independent C parity + column atomic commit |
| `keccak_rho_pi_wire.sv` | Combinational ρ then π | 0 extra cycles |
| `keccak_chi_row.sv` | χ: 5 cycles, one row/cycle; `frozen_state`; ι on row0 | Lane-serial χ; FT: independent χ parity |
| `keccak_iota.sv` | XOR RC into lane (0,0) | Standard ι |
| `keccak_parity_predictor.sv` | Modules `keccak_theta_parity`, `keccak_chi_parity` | **Idea:** predict output lane parity from **inputs**, never re-encode the result |
| `keccak_lane_parity.sv` | Compare `^lane` vs predicted; block write on mismatch | Detect + atomic commit; **no bit flip** |
| `keccak_state_bank.sv` | 25 lane registers, per-lane clocks | Clock-gating granularity = lane |
| `sha3_low_power_gating.sv` | Negedge latch-like enable FF + AND gate ICG | Sleep unused 20 lanes; **schedule gating, not HD gating** |
| `sha3_output_formatter.sv` | 256-bit digest as 32-bit beats | Host-friendly squeeze |

**Intentionally absent from current `syn.tcl`:** `keccak_hamming64.sv`, `keccak_lane_ecc.sv`, `keccak_ft_region.sv` (legacy).

## 3.2 `src/sysVerilog/00_TESTBED/` — simulation, not DC

| File | Role |
|---|---|
| `filelist.f` | VCS/Verilator file list (parity RTL + PATTERN*) |
| `TESTBED.sv` | Harness; ifdef selects PATTERN vs PATTERN_FT |
| `PATTERN.sv` | Functional SHA3-256 / throughput (18 cases) |
| `PATTERN_FT.sv` | Parity inject + replay (`+define+FT_PATTERN`); 64-bit masks; includes even-bit **miss** cases |
| `PATTERN_FT_1600.sv` | **Legacy** 1600 Hamming TB; **incompatible** with current core |
| `Makefile` | `vcs_rtl`, `vcs_rtl_ft`, `vcs_rtl_no_ft`; `PROCESS?=TSMC40`; `vcs_rtl_ft_1600` **errors on purpose** |
| `run_verilator.py` | Portable sim (`--mode all\|unit\|ft\|normal\|baseline`) |
| `tb_parity_predictor.sv` | Unit predictor checks |
| `tb_hamming64.sv` | Legacy Hamming unit test |

## 3.3 `src/sysVerilog/02_SYN/` — Design Compiler

| File | Role |
|---|---|
| `syn.tcl` | Analyze listed RTL; `elaborate ... -parameters FT_ENABLE=$FT_ENABLE`; `DESIGN=SHA3_parity` or `SHA3_base`; env `CLK_PERIOD`; FT=1: compile predictors separately, `dont_touch`, no ungroup; inject ports `set_case_analysis 0` |
| `syn_1600.tcl` | **Hard error** — points to commit `0798e0b` |

Reports: `Report/SHA3_parity.{area,timing,power}` or `SHA3_base.*` — **not** old `SHA3.area`. Sweep scripts that still grep `SHA3.area` yield `REPORT_MISSING`.

## 3.4 Scripts beside RTL

| File | Role |
|---|---|
| `src/sysVerilog/sweep_dc.sh` | Clock sweep; `FT_ENABLE` selects DESIGN name; `E/bit` from DC reports; cycles/block **240** for no-fault |
| `src/sysVerilog/my_sweep.sh` | Older/simpler sweep; same DESIGN naming |
| `hamming64_sim/` | Standalone old Hamming TB runner |

## 3.5 Legacy RTL (do not mix into current syn)

| Dir | Role |
|---|---|
| `01_RTL_legacy_secded/` | Four files: (72,64) encode/decode + `keccak_ft_region` + old pkg. README: full design = **`0798e0b`** |
| `01_RTL_1600Hamming_test/` | **3 overlay files only** (`sha3_pkg`, `keccak_hamming64`, `keccak_lane_ecc`) for (1612,1600). Must overlay onto **SECDED** `01_RTL`, never onto parity core |

## 3.6 `src/veriCode/`

C++/Python SHA-3 golden (`KeccakCore`, `SHA3`) for software digest checks. Not the ASIC microarchitecture.

## 3.7 `others/` — narrative + measured tables

| File | Role |
|---|---|
| `parity_predictor_design.md` | **Canonical** formulas, fault model, syn flow, 15% target honesty |
| `parity_validation.md` | Verilator/slang results |
| `scheduler_replay_interface.md` | Hold/replay timing contract (parity era) |
| `FT論文導讀與算法講義.md` | Historical lecture (SECDED-centric); header says superseded by parity notes |
| `fault detection and recover分工說明.md` / `分工說明.md` | Old team split (Person A/B Hamming). History only |
| `sweep_summary_C3.csv` / `_lane.csv` / `_1600.csv` | Sweep tables used in PDFs |
| `SHA3_FT_lane_vs_1600_sweep_report.pdf` | Lane vs 1600 vs C3 (10 ns + Fmax + Emin) |
| `make_ft_lane_vs_1600_report.py` / `make_ft_parity_vs_c3_report.py` | PDF generators |
| `SHA3_block_diagram.drawio` | Block diagram source |
| Local-only if present: `開會說明_FPGA_PUF_TRNG.md`, advisor Hamming review md | Planning / oral scripts |

## 3.8 `references/`

`README.txt` only in git: FIPS 202; Pessl 2013 ULP SHA-3; model A 1-round/cycle; model B lane/step serial; model C unified SHA3/SHAKE + fault-resilient. Fetch PDFs yourself.

---

# 4. Design architecture mapped to code (ideas)

```
msg 1088b → pad_domain → absorb_xor → state_bank (25×64, lane clocks)
                ↑
         ctrl_fsm  sponge: IDLE/ABSORB/RUN_ROUND/SQUEEZE
                ↓
    round_scheduler: 24 × (θ 5cyc → ρπ wire → χ 5cyc) = 240 cyc
                ↓
         formatter → 32b out, 256b digest
```

**Low-power idea:** only lanes in `lane_active` get `lane_clk`. θ one **column** (5 lanes), χ one **row** (5 lanes). Gating = **who is scheduled**, never “HD≈0 skip χ” (that would break the hash).

**FT idea (current):**

- Predictor cone **from pre-op inputs** (`keccak_theta_parity` / `keccak_chi_parity`).
- Checker: per active lane even parity vs prediction; θ also checks C words before checkpoint.
- On fail: **do not write** the whole column/row; `hold` index; next cycle `replay` same inputs.
- Permanent fail → stall forever rather than emit a bad digest.
- `FT_ENABLE=0`: same datapath without predictor/checker; **still has frozen/C-checkpoint/hold ports** → **not equal to C3**.

**Injection (TB only):** 64-bit data masks; plus C/D inject. Synthesis ties valids to 0.

θ: `keccak_theta_serial.sv` + predictor in `keccak_parity_predictor.sv`.  
χ: `keccak_chi_row.sv` + same predictor file.  
Commit policy: `keccak_lane_parity.sv`.  
Time: `keccak_round_scheduler.sv`.

---

# 5. Heart of the project (story order)

Write the paper as **evolution**, not three unrelated chips.

1. **ULP SHA3-256 (C3).** Shrink cycles (merge θ C/D, drop idle cycles) and clock-gate idle lanes. 10 ns E ≈ **4.17 pJ/bit** (40 nm, vectorless). Intellectual cousin: Pessl-style serial/low-power keccak, **not** a 1-round-per-cycle core.

2. **Lane-level recover with SECDED.** Because the datapath already thinks in 64-bit lanes, put **(72,64)** on each lane: 1-bit correct in place, 2-bit → **selective replay** of that column/row (not full keccak-f). Compare **1600-bit single code** as fairness experiment: **no PPA win**, worse Fmax (deeper XOR tree).

3. **Advisor: SECDED too fat for a “breakthrough.”** Drop correction. **Algebraic parity + replay** (θ linear; χ degree 2). Cheaper than SECDED on the **same** C3 ruler (+45% area vs +100%), still **above 15%**. Function class = **detect + local retry**, not Hamming.

4. **Optional next (unimplemented):** FPGA RO bank for PUF (compare frequencies) and TRNG (sample jitter). SHA-3 stays a **correct** hash/KDF/conditioner. Not overclock-Keccak-as-PUF. Entropy for 800-90B is **physical noise**, not XOR/SHA-3.

---

# 6. Lab workstation (folder layout and commands)

School ASIC flow uses a **per-design directory** created by `build <name>`:

```
<design>/
  00_TESTBED/   # sim: Makefile, filelist, PATTERN, TESTBED
  01_RTL/       # copy GitHub 01_RTL here
  02_SYN/       # syn.tcl, 01_run_dc, Report/, Netlist/, .synopsys_dc.setup
  03_GATE/      # after syn; needs vcd→fsdb history for their flow
```

**Copy for current parity synthesis:** all **15** current `01_RTL/*.sv` **including** `keccak_parity_predictor.sv` and `keccak_lane_parity.sv`; replace `02_SYN/syn.tcl`. Sweep script lives **one level above** `02_SYN` as `../sweep_dc.sh`. **Do not** overlay `01_RTL_1600Hamming_test`. **Do not** copy Hamming into analyze list.

Shell on that station is often **tcsh** (`>&` not bash `2>`).

```tcsh
# RTL sim (inside 00_TESTBED)
make vcs_rtl
make vcs_rtl_ft
make vcs_rtl_no_ft
# nWave: make nWave   # vcd2fsdb

# Single 10 ns syn (inside 02_SYN) — paper primary PPA point
setenv CLK_PERIOD 10
setenv FT_ENABLE 1
./01_run_dc
# reports: Report/SHA3_parity.area .timing .power

setenv FT_ENABLE 0
./01_run_dc
# Report/SHA3_base.*  → incremental predictor cost, NOT C3

# Sweep (from 02_SYN); 240 = no-fault cycles/block
setenv FT_ENABLE 1
nohup ../sweep_dc.sh 10 1 0.1 240 >& /dev/null &
```

`01_run_dc` must pass environment into `dc_shell -f syn.tcl`. If CSV is `REPORT_MISSING`, filenames (`SHA3` vs `SHA3_parity`) or DC errors; read `syn.log` / `dc_run.log`.

**Paper denominator for “overhead %”:** C3 / release1 numbers in `sweep_summary_C3.csv` (same 10 ns, 40 nm, vectorless). Not `FT_ENABLE=0`.

---

# 7. Constraints the paper must not violate

- Algorithm is **SHA3-256**, padding `01`, squeeze 256. SHAKE/PQC = formatter/padding, **not** a new permutation; SHAKE128 also changes **rate**.
- Hamming **code** ≠ Hamming **weight** ≠ Hamming **distance**. SCA/AFA/min-weight trails are **other papers**; AFA is an **attack** (Luo ePrint 2017/113), opposite of FT.
- Parity **≠** SECDED. Odd flips detectable; **even flips on one lane miss** (TB asserts wrong digest).
- Do not skip χ because capacity bits were zero or HD was zero.
- Do not claim masking / TVLA / sub-1 pJ / 90B / PUF uniqueness without new data.
- FPGA PUF: same bitstream, locked P&R; inject ports are the **opposite** of a PUF.
- Conditioning (SHA-3, XOR) **does not create entropy** (NIST SP 800-90B).

---

# 8. vs literature — where we win / lose (re-verify on arXiv / IACR)

Use the **same comparison set** already given to the advisor: **RERO, Ewert, ArchHC, Impeccable**, plus **internal SECDED**. Platforms differ; only internal SECDED is same 40 nm / 10 ns / same C3.

| Work | Class | Overhead (as used in team PDFs) | Direct PPA? | Win / lose vs **current parity** |
|---|---|---|---|---|
| **This C3** | ULP lane-serial hash | baseline | yes | Energy story lives here |
| **This lane SECDED** | 1-bit correct + 2-bit replay | +100.3% area, +81% E | yes | Parity **wins PPA**, **loses correction** |
| **This 1600 SECDED** | one fat code | slightly worse than lane | yes vs lane | Abandoned for PPA |
| **This parity+replay** | detect + local replay | +44.9% area, +30% E vs C3 | yes vs C3 | No-fault throughput **same as C3** |
| **RERO** Bayat-Sarmadi IEEE TCAD 2014 | Always rotated recompute; detect; extra 25×64 FFs | +4.4–7.6% on **65 nm 1-round/cycle** fat core; throughput also down ~6–12% | **no** | They **win area %**; we **win** “no-fault extra round” and **local** retry. Different time budget. Fetch: author PDF / IEEE |
| **Ewert** c-plane / z-sheet parity (team: arXiv:2512.03616) | Parity detect | ~+56% | magnitude only | Similar class; we slightly **lower %** and add column/row replay. Both miss some even patterns. **Re-fetch arXiv** |
| **ArchHC** Sensors 2022 Hamming on FPGA | 1-bit correct | LUT ~12× | **no** | They **win function** (correct). We **must not** equate. |
| **Impeccable** SoC | Strong integrity | ~3.2× | **no** | Cheaper % but much **weaker** protection scope |

**Competitiveness sentence (approved team wording):** competitive on “ULP SHA-3 + detect and **local** recover, **no-fault throughput held**”; **not** competitive on minimum detect overhead (RERO) or 1-bit correction (ArchHC/SECDED). **Worse PPA than RERO is not the same as a weaker design** if the extra area buys in-place replay and an unchanged 240-cycle hash.

**Please re-read (open access first):**

- FIPS 202: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf  
- Keccak specs: https://keccak.team/keccak_specs_summary.html  
- SP 800-90B: https://csrc.nist.gov/pubs/sp/800/90/b/final  
- RERO: search “Efficient and Concurrent Reliable Realization of the Secure Cryptographic SHA-3”  
- ArchHC: MDPI Sensors 2022 SHA-3 Hamming TMR  
- AFA (do not confuse with FT): ePrint 2017/113  
- Masked SHA-3 area ~3×: TCHES 2024 “Breaking Ground… Masked SHA-3” (SCA, **not** this thesis)  
- Pessl et al. ULP SHA-3 (references list)

---

# 9. What to write next (paper), what not to start coding unless asked

**Paper-ready:** C3 energy; lane vs 1600 SECDED; parity vs C3 10 ns; honest fault model; related-work table with “comparable / not comparable” column.

**Need more lab data if claimed:** VCS on workstation for 153 FT cases; gate-level inject; FT_ENABLE=0 area (appendix only); sweep Fmax for parity.

**Not in repo:** AXI wrapper, PicoRV32, SHAKE formatter, RO-PUF, neoTRNG, 90B datasets, multi-board uniqueness.

Oral FPGA plan (if local): `others/開會說明_FPGA_PUF_TRNG.md`.

---

# 10. Pointers — read these, don’t trust memory

Canonical design: `others/parity_predictor_design.md`  
Replay wires: `others/scheduler_replay_interface.md`  
Sim evidence: `others/parity_validation.md`  
Syn list of truth: `src/sysVerilog/02_SYN/syn.tcl` analyze list  
Top I/O + `FT_ENABLE`: `src/sysVerilog/01_RTL/sha3_ultra_low_power_top.sv`

End of handoff. If a file listed here is missing, **search the tree**; do not invent contents.
