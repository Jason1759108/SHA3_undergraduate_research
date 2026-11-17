# 檢查與證據

在src/sysVerilog/PUF_TRNG/PUF執行：

```sh
python3 verification/check_handoff.py
python3 -m unittest discover -s verification -p 'test_*.py' -v
python3 verification/recheck_evidence.py
```

check_handoff檢查正式RTL hash、filelist/本地文件連結、Python/Notebook語法及入口。host tests包含MMIO、訓練規則、雙板比較與千次紀錄驗證的合成fixture，不能當作FPGA實測。

recheck_evidence重算原始baseline與共同bitmap、驗證111次及每板1000筆原始證據。historical evidence中的原始程式副本只用於hash溯源，沒有作為正式執行入口。compare_boards/verify_1000的路徑已適配docs/results，但核對的輸入與測量紀錄保持原bytes。

methodology_diagnostics、diagnose_methodology、compare_methodology_timing、finalize_methodology與check_reports仍被Vivado部署流程使用，不是可隨意刪除的快取。
