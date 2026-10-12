# SHA3-256：Algebraic Parity + Replay

主 RTL 位於 `src/sysVerilog/01_RTL`。以 θ／χ 輸入的代數奇偶預測取代 SECDED correction；任一偵測失敗即保留整欄／整列並於下一拍重算，重算再次失敗也不放行。

- [架構、公式、故障模型、測試與合成方式](others/parity_predictor_design.md)
- [實際 RTL 驗證紀錄](others/parity_validation.md)
- [Replay 時序合約](others/scheduler_replay_interface.md)
- 主回歸：在 `src/sysVerilog/00_TESTBED` 執行 `make vcs_rtl`、`make vcs_rtl_ft`、`make vcs_rtl_no_ft`。
- 可攜回歸：`python3 src/sysVerilog/00_TESTBED/run_verilator.py --mode all`（需 Verilator）。
- 面積目標為相較無 FT ≤15%；尚待同製程／同約束合成，不能視為已達成。
- 單 lane parity 存在偶數 bit 翻轉盲點；它不提供 SECDED 等價的雙位元偵測保證。

## 原工作站操作筆記

在工作站上面可以用build [名稱]來創建我們熟悉的有00 01 02 03的資料夾
1. 先用build sha3_pkg
2. 進到../sha3_pkg/01_RTL/sha3_pkg.sv貼上github上的檔案
3. 創建任何需要import pkg的區塊時，一樣先在../ 用build name
4. 在../name/01_RTL/name.sv參考github上test資料夾裡面test.sv的寫法實作
5. 在../name/00_TESTBED/參考github上test資料夾裡面的寫法寫filelist跟需要的PATTERN和TESTBED
6. 然後就可以用我們熟悉的方法跑01，要用nWave打開vcd可以調filter
7. 開過vcd就會自動產出fsdb(規避TESTBENCH直接寫語法錯誤)
8. 跑02要調整tcl，我有把這整個設計用的調整好傳上來
9. 7 有做過並且02有跑03就可以正常用
