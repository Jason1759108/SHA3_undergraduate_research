# Parity + Replay 驗證紀錄

日期：2026-10-12。這是實際 RTL 模擬結果，不是 Python 演算法模型的結果。

| 執行模式 | 結果 |
|---|---|
| unit | [SUCCESS] 33000 predictor/checker checks on 1000 random states |
| normal | [SUCCESS] All 18 SHA3-256 test cases passed! |
| ft | [SUCCESS] All 153 parity/replay cases passed |
| baseline | [SUCCESS] All 18 SHA3-256 test cases passed! |

另以 slang 12.0.0 對 normal、ft、baseline、unit 四種組合完整編譯／elaborate：各 0 errors、0 warnings。
模擬使用 Windows Verilator Python distribution 5.48.0（其 runtime banner 顯示 5.49）、Zig 0.16.0。
為避免該 Windows Verilator 對 unpacked 常數表的 elaboration 問題，RHO_OFFSET／PI_Y_MAP 改為索引、數值完全相同的 packed 常數表。

## 可重現命令

標準 Verilator 環境，在 repo 根目錄執行：

```sh
python3 src/sysVerilog/00_TESTBED/run_verilator.py --mode all
```

本次 Windows 工具保留在被 Git 忽略的 `.tmp/`，可執行：

```text
python src/sysVerilog/00_TESTBED/run_verilator.py --mode all --verilator .tmp/parity-tools/verilator/bin/verilator_bin.exe --zig .tmp/parity-tools/ziglang/zig.exe
```

實際執行時使用可用的 Python executable；本機 Microsoft Store 的 `python` alias 無法執行，故使用 Codex bundled Python。
Zig 在 Windows sandbox 內回報暫存檔／Unexpected 錯誤，成功的 C++ build 經核准在 sandbox 外執行；原始碼、工具、快取、產物皆在專案目錄。
每模式的 `verilator.log`、`build.log`、`simulation.log` 位於 `.tmp/sha3_validation/<mode>/`。

## 結果的範圍

- 153 個 FT 案例中有兩個刻意驗證 parity 偶數翻轉漏偵測：預期沒有 fault、digest 錯誤。其餘注入案例要求偵到錯誤、原子保留 state、重跑後 digest 正確。
- C 注入含所有 5 個 C word、與 D[0] 無關的 C[2]、連續 3 拍 C fault；全部確認能重新算 C，而非保存錯誤 checkpoint 後永久停住。
- lane / D 連續故障測試含 5 拍；每個失敗拍必須維持整個 state 與 round、阻止完成，解除後須成功結束。
- 空訊息 baseline 的 TB 計數為 241（240 運算拍 + 交握）；單次 fault 為 242、連續 5 拍 fault 為 246。
- 一般回歸包含 empty、短字串、padding 邊界、多區塊與吞吐測試；FT 回歸另含 135/136/137/272 bytes 訊息。
- Verilator warnings 仍包括原有不同 lane clock 寫同一 unpacked state array 的 MULTIDRIVEN、formatter／padding 的 width / case，以及刻意採遞增索引 packed table 的 ASCRANGE；沒有 latch 或 combinational-loop 診斷。slang 四種配置均無警告。
- 未執行 VCS、Design Compiler、gate-level fault injection 或製程面積量測。合成腳本已更新，但須在原工作站驗證 mapping、predictor preservation 與 timing，才能判定 +15% 面積目標。

演算法推導、介面與故障模型見 [設計筆記](parity_predictor_design.md)。
