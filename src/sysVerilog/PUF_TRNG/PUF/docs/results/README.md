# 證據目錄

先讀 [驗證總報告](../VALIDATION.md)，不需要逐一開啟所有原始檔。

- `single_board/`：原完整PUF的模擬/routed報告與來源manifest；大型報告gzip無損保存。
- `two_boards/`：兩板各自bitmap基準、共同bitmap、第一次失敗前綴與接續固定排程。負面結果不得刪除。
- `rebuild_1000/`：各板原bitmap/helper固定1000次，包含provenance、凍結輸入、逐筆JSONL與Notebook。
- `handoff_20261117/`：這次整理後的實際檢查，不與舊板測混為同一建置。

*.original.md及evidence中的原程式保留原bytes和舊路徑，只供溯源。正式執行使用sim、software、scripts、verification。歷史bitstream重建/重新整合後應重新註冊，原實驗身份碼不是產品秘密。
