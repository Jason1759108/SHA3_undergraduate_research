# SHA3 代數奇偶預測與 Replay 設計筆記

日期：2026-10-12。以下區分官方演算法、由其推導的等式，以及本專案設計建議；不把研究目標當成已量測成果。

## 演算法依據與預測公式

Keccak-f[1600] 的 state 為 25 個 64-bit lane；θ、ρ、π、χ、ι 的定義以 [NIST FIPS 202 §3.2](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf) 與 [Keccak 作者提供的規格摘要](https://keccak.team/keccak_specs_summary.html) 為準。令 `P(V) = XOR_z V[z]`，`p[x,y] = P(A[x,y])`，x/y 索引皆 modulo 5。下面的 parity 關係是本筆記根據官方等式的代數推導。

### θ：只需輸入 lane parity

官方定義 `C[x] = XOR_y A[x,y]`、`D[x] = C[x−1] XOR ROL(C[x+1],1)`、`T[x,y] = A[x,y] XOR D[x]`。因循環旋轉不改變全 lane parity：

```text
cP[x]       = XOR_y p[x,y]
dP_pred[x]  = cP[x−1] XOR cP[x+1]
tP_pred[x,y]= p[x,y] XOR dP_pred[x]
```

因此預測 D 與 θ 輸出不需要另一套 64-bit C/D 運算。本次設計在 θ 的 col0 計算 5 個 64-bit C 與 5 個由輸入 lane parity 獨立產生的 cP。先逐一比較 `P(C[x])` 與 cP，並檢查 col0 輸出；全部通過才保存 C/cP 與提交 col0。失敗時原始 state 尚未修改，下拍重新計算全部 C。後續每拍由 C 重算 D，取消 D 的 SECDED 與暫存器。D 的錯誤透過五個 θ 輸出 lane 的 parity mismatch 偵測；沒有另做 D correction 或 D parity register。不要以可能已受損的 D 重新產生預期 parity。

### ρ/π：parity 跟著 lane 換位

旋轉維持 lane parity；π 只換位。因此 `bP[y,2x+3y] = tP[x,y]`。這能傳遞既有 parity，但不能偵測 lane 內純旋轉偏移錯誤，因為任何旋轉都保留這個 signature。

### χ + ι：需要輸入位元之間的乘積項

官方 χ 為 `Q[x,y] = B[x,y] XOR ((NOT B[x+1,y]) AND B[x+2,y])`。使用 GF(2) 中 `(NOT u) AND v = v XOR (u AND v)`，可得到不同於主資料路徑形式的獨立預測器：

```text
qP_pred[x,y] = bP[x,y] XOR bP[x+2,y]
              XOR P(B[x+1,y] AND B[x+2,y])
outP_pred[0,0] = qP_pred[0,0] XOR P(RC[round])
outP_pred[x,y] = qP_pred[x,y]  // 其餘 lanes
```

χ 不能只由 5 個輸入 lane parity 決定，因為 AND 的 parity 取決於位元位置的交集。預測器仍需要讀取對應 row 的完整輸入，形成 AND 後做 reduction XOR；不需要 Hamming Weight 計數。選擇 RC 的 round index 若與資料路徑共同出錯，也可能無法偵測。

若改為整個 320-bit row 只有一個 parity，線性項在 XOR 五個輸出時相消，可進一步化簡為：

```text
rowP_pred[y] = XOR_x P(B[x,y] AND B[x+1,y])
```

row0 再 XOR `P(RC)`。這會讓不同 lane 的錯誤互相抵銷，第一版建議使用每個 active lane 一個 parity，保留定位能力。是否改成 row signature，應依合成面積與故障模型決定。

以上 θ lane、χ lane、χ row 等式已用 1,000 組隨機 1600-bit state 做代數交叉檢查；這不代表 RTL 或故障覆蓋率已驗證。

## 本專案介面與時序建議

本次 θ 設計把整個 column 視為不可分割的寫入單位：5 個 lane 全部通過才一起寫回。失敗時此 column 保留原始輸入，下拍由同一 C checkpoint 重算 D 與當前 column，因此可移除原本 1600-bit `theta_base`；先前成功的 column 無須倒回。預測使用尚未寫入的當前 column parity，以及保存的相鄰 C parity。D 注入改為選定 D 上的原始 64-bit mask。

χ 同樣採整 row 原子提交，並以 `frozen_state` 保存完整輸入快照（包含 row0）：開始當拍用 live input，後續與 replay 用對應快照。所謂「前一拍」應解讀為運算前狀態，不能誤取已部分更新的 state。

比較 `P(actual_output)` 與 `predicted_parity`，任一有效 lane 失配就阻止整 column／row 寫入、保持索引並 replay。移除可修正／不可修正分類、FROM0 與 replay kind；replay 本身仍須檢查，失敗時繼續保持並重試。持續故障可能永遠無法完成，不能在重試仍失敗時放行 digest。

預測器不能接到待檢查輸出後再產生一份 parity 與自身比較，那只會驗證注入點之後的傳输，無法偵測注入點之前的計算錯誤。也應確認 synthesis 是否把主路徑與預測器的等價子式合併，造成實體共用故障點；RTL 寫成兩個 expression 不代表物理獨立。

## 故障模型與面積目標

單 lane parity 可偵測該 lane 輸出上任意奇數個翻轉；同 lane 偶數個翻轉會抵銷。兩個不同 lane 各一個翻轉仍可由各自 checker 偵測。這些是 parity 定義的直接結果，不能將新的設計宣稱成 SECDED 的雙位元偵測等價替代。

本版以 C checkpoint、χ 快照、控制器、預測器與 comparator 為可信來源。共享輸入或快照先受損，之後計算與預測可能相互一致；C checkpoint 持續損壞也可能導致無限重試，replay 本身不能修復它。若要涵蓋 state register / 快照儲存錯誤，需要在可信寫入時保存 parity，讀取時核對；若要恢復它們，還需要可信來源或更大範圍 checkpoint。不可把計算路徑注入測試的成功延伸宣稱成所有儲存／控制故障都可恢復。

`+100.3%` 是使用者提供的既有數據，尚未在本次研究重新量測。`≤15%` 是目標，不能僅靠上述公式保證；χ AND/XOR tree、checker、replay 快照、mux、clock gating 與時序修復都占面積。SECDED 也不是計算完整 Hamming Weight；它的成本主要來自多組 parity、syndrome、解碼與 correction mux，應正確描述移除的硬體。

最終請用同一製程庫、時脈／I/O 約束與合成流程，比較無 FT、原 SECDED、Parity + Replay 三版本：`overhead = (A_FT − A_base) / A_base`。報告總 cell area、sequential / combinational 分項、timing、正常延遲及故障重跑延遲；量測之前不宣稱已達 15%。

## 已實作介面與驗證入口

- `keccak_parity_predictor.sv`：θ 與 χ 的獨立預測器。
- `keccak_lane_parity.sv`：每 active lane 一個 parity comparison，任一 mismatch 或 C checkpoint fault 時整個操作不提交。
- `keccak_round_scheduler.sv`：每次 fault 都 hold，下一拍 replay；沒有 replay kind 或每 round 一次的上限。永久 fault 會停留，不會超過重試次數後輸出未驗證結果。
- Top 的 `FT_ENABLE` 預設 1；設成 0 可編譯同一資料路徑的無 FT 對照組。
- `ft_inject_mask`、`ft_d_inject_mask` 改為 64-bit，bit k 直接翻轉資料 bit k，與舊 72-bit codeword 位置不相容。
- 新增 `ft_c_inject_valid/col/mask`，在 C 計算後、C checkpoint 檢查前注入；col 為 0～4，mask 為 64-bit。
- lane 注入只作用於當拍有效 θ／χ lane；C 注入只作用於 col0 的 C 計算；D 注入只作用於當前 column。合成將三個注入 valid 綁定為 0。

從 `src/sysVerilog/00_TESTBED` 執行：

```sh
make vcs_rtl         # 原本的 18 個一般功能／throughput 案例
make vcs_rtl_ft      # 153 個 parity / replay 整合案例
make vcs_rtl_no_ft   # 關閉 FT，同樣的 18 個功能案例
python3 run_verilator.py --mode all
```

`run_verilator.py` 支援 Linux 的 Verilator / C++ 環境；Windows 可傳入
`--verilator PATH/TO/verilator_bin.exe --zig PATH/TO/zig.exe`。
工具需預先安裝；腳本不下載任何工具。所有產物與記錄位於 repo `.tmp/sha3_validation/`。
`--mode unit` 的獨立 RTL 測試涵蓋 1,000 個固定 seed 隨機 state、33,000 個明確計數的公式／原子提交檢查，另有 clean-write、inactive、even-bit 與跨 lane 雙錯誤斷言。

FT 整合案例涵蓋 64 個資料 bit、θ／χ 各個 column／row、24 個 round、C 與 D 路徑、連續故障、重跑中再故障、同一 round 的多次故障、最後操作、多 block 與額外 padding block。兩個偶數位元案例是**預期漏偵測且 digest 錯誤**的覆蓋率特性測試，不是成功修復案例。核心仍為 240 運算拍；TB 從 start_process 到 process_done 的計數包含一拍交握，baseline 記錄為 241。每個被偵測而失敗的拍增加一拍。

## 合成與面積比較

沿用工作站原本的 library setup / `01_run_dc`，同一 `CLK_PERIOD` 分別執行：

```sh
FT_ENABLE=0 CLK_PERIOD=10 ./01_run_dc
FT_ENABLE=1 CLK_PERIOD=10 ./01_run_dc
```

`syn.tcl` 分別輸出 `Report/SHA3_base.area`、`Report/SHA3_parity.area` 及對應 timing / power / netlist。以新的無 FT 對照組量測本次增量，也要與原本論文使用的 C3 baseline 另列絕對面積；不得替換 baseline 後仍沿用舊 +100.3% 當作同一組量測。

預測器先獨立 map，再設 `dont_touch`、禁止 boundary optimization 與 ungroup，避免 synthesis 把等價預測／結果比較化成常數。這不等於已驗證的 gate-level fault coverage；合成後仍須檢查 predictor instance、comparison 與 fault→hold/writeback 路徑存在，確認沒有 unmapped cell，並以 mapped netlist 做注入回歸。預測器獨立編譯以同一 CYCLE 作 max-delay 上限；最終可用時脈仍以 top timing 報告為準。

本機無 Design Compiler／製程庫，因此尚未產生本次面積、功耗或時序結果，也尚未證明 ≤15%。

## 舊 SECDED 對照

完整可執行的舊版固定在 commit `0798e0b9ed8ba1b73a2cdd427b2441c755fb4903`。
要重跑舊 lane／1600-bit SECDED，請在獨立目錄匯出該 commit，使用該版完整 RTL、TB 與合成脚本。
`01_RTL_legacy_secded` 僅保存四個舊 ECC 原始檔與 Hamming 單元測試所需 package，排除於主 filelist。
`01_RTL_1600Hamming_test` 與 `PATTERN_FT_1600.sv` 亦屬歷史對照；不可 overlay 到新的 parity 核心。
原本的 `vcs_rtl_ft_1600` / `syn_1600.tcl` 會明確報錯並指向舊 commit，以免誤用不同介面。
