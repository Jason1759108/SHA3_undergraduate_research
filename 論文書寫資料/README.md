# SHA3 專題與可選論文資料

老師確認的論文方向：**V0 基準、V1 1600-bit SECDED、V2 lane-level SECDED**，在同一 C3 序列化架構與 10 ns 合成條件下比較。V3 仍是專題成果與版本紀錄，**不進本篇論文**。

英文稿改在共享 Overleaf 專案編輯，使用 IEEEtran 兩欄 LaTeX。先讀：

1. [共同 Phase／章節／圖表分工](./分工說明與模板/論文_共同Phase排程與分工.md)
2. [Person A 手冊](./分工說明與模板/論文_PersonA工作手冊.md)與[Person B 手冊](./分工說明與模板/論文_PersonB工作手冊.md)
3. [Overleaf 建立與共編指南](./分工說明與模板/Overleaf建立與共編指南.md)及可上傳的 [專案 ZIP](./Overleaf_IEEE_專案.zip)
4. [實驗資料與指標說明](./分工說明與模板/實驗資料與指標說明.md)；正式數字見 [V0／V1／V2 單 block 主表](./工作站結果/單block正式週期/V012_single_block_10ns.csv)。

V0/V1/V2 正式 RTL、10 ns CSV、135-byte 週期與參考論文保留在本資料夾，**不須上傳 Overleaf**。三版都量到單 block **258 cycles**，以整顆 SHA3 估計功耗計算的 P/T 依序為 **4.819889350／8.428835872／8.075392356 pJ/有效輸入 bit**。原 4096-byte 與 240-cycle P/T 欄位只作歷史紀錄，不當本文指標。已完成補測的上傳包與臨時測試資料不放在論文工作區。

Overleaf 是論文正文的共同工作區；本地不再保留 personA／personB 段落工作區與 Word 起始範本。本文沒有投稿 IEEE 的承諾，IEEEtran 只作老師指定的版型。
