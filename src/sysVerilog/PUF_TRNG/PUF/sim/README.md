# PUF 模擬：依測試範圍選擇入口

從 repository 根目錄進入 `src/sysVerilog/PUF_TRNG/PUF`。以下三套只使用正式 `rtl/`，不引用 SHA3 或歷史快照。

|測試名稱|Testbench / top|Pattern|測試範圍|
|---|---|---|---|
|PUF_AXI_RO|`TESTBED_PUF_AXI_RO.sv` / `TESTBED_PUF_AXI_RO`|`PATTERN_PUF_AXI_RO.sv`|AXI4-Lite→人工RO波形→真實Counter/CDC→PUF→SECDED完整整合，含320組raw診斷與故障|
|PUF_CORE_COUNT|`TESTBED_PUF_CORE_COUNT.sv` / `TESTBED_PUF_CORE_COUNT`|`PATTERN_PUF_CORE_COUNT.sv`|人工count後端的PUF核心，測bitmap/helper、多數決、握手、超時與ECC限制；沒有RO波形或AXI|
|PUF_ECC_SECDED|`TESTBED_PUF_ECC_SECDED.sv` / `TESTBED_PUF_ECC_SECDED`|`PATTERN_PUF_ECC_SECDED.sv`|獨立SECDED單元，測無錯誤、單錯誤修正、雙錯誤偵測|

Testbench 負責接線與波形輸出；Pattern 負責刺激、預期答案與檢查。檔名與其中的module名稱一致。詳細phase與信號見 [PATTERN_GUIDE](../docs/PATTERN_GUIDE.md)。

## 工作站 VCS（進入 sim/ 執行）

|命令|Filelist|波形檔|
|---|---|---|
|`make vcs-axi-ro`|`filelist_puf_axi_ro.f`|`puf_axi_ro.vcd`|
|`make vcs-core-count`|`filelist_puf_core_count.f`|`puf_core_count.vcd`|
|`make vcs-ecc-secded`|`filelist_puf_ecc_secded.f`|`puf_ecc_secded.vcd`|

VCS需支援SystemVerilog/package及有授權。不要同時指定三個top。本地使用Verilator檢查，學校VCS尚未實跑。

## Verilator（從 PUF 根目錄執行）

```sh
python3 sim/run_sim.py --mode axi-ro --vcd
python3 sim/run_sim.py --mode core-count
python3 sim/run_sim.py --mode ecc-secded
```

或在PUF根目錄執行 `make axi-ro`、`make core-count`、`make ecc-secded`。輸出在 `build/sim/axi-ro/`、`build/sim/core-count/`、`build/sim/ecc-secded/`。完整axi-ro需要 `--vcd` 才寫波形；core-count/ecc-secded保持原本的dump行為，會輸出對應VCD。

Windows可指定 `--verilator /path/verilator_bin.exe --zig /path/zig.exe`，並用 `--build-dir` 選較短輸出根。完整axi-ro編譯/執行較慢。`--translate-only` 只做翻譯/elaboration，不代表回歸執行通過。

`ro_wave_model.sv` 只產生虛構RO時序，真實計數/CDC/PUF/ECC來自正式RTL；`puf_count_model.sv`只用於核心快速回歸。實體LUT回授不加入預設零延遲模擬，不能用人工模型宣稱硬體熵。

## 舊命令相容

`make vcs/vcs-core/vcs-ecc` 分別轉到新的三個VCS入口；Python `--mode wave/core/ecc` 仍可使用，分別轉到 `axi-ro/core-count/ecc-secded`，輸出也使用新目錄名。舊檔名和舊top不保留重複來源，請更新自己額外的工作站指令。

完整舊→新檔名對照見 [TEST_NAMING](../docs/TEST_NAMING.md)。歷史測試紀錄中的舊名稱保留原貌，不是目前入口。
