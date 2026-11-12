# Overleaf 建立與兩人共編

更新日期：2026-11-13。這是把本地 [Overleaf_IEEE_專案.zip](../Overleaf_IEEE_專案.zip) 建成共享 IEEEtran 草稿的操作指引。此工作區沒有連到你個人的 Overleaf 專案，因此尚未替你上傳或邀請組員。

## 一次建好專案

1. 登入 [Overleaf](https://www.overleaf.com/)；在 Projects 頁面選 **New Project → Upload Project**，選本地 `論文書寫資料/Overleaf_IEEE_專案.zip`。Overleaf 官方說明指出 ZIP 內的資料夾會一併重建。[官方上傳指南](https://www.overleaf.com/learn/Uploading_a_project)
2. 進入新專案後確認左側有 `main.tex`、`references.bib`、`sections/`；若畫面不是 `main.tex`，在 **Menu → Main document** 選 `main.tex`。
3. 按 **Recompile**。本模板使用 `\documentclass[conference]{IEEEtran}` 與 Overleaf 已提供的 IEEEtran class／bibliography style；不需自行複製截圖裡其他論文的標題、作者或 `IEEEtran.bst`。若編譯器曾被改動，選 pdfLaTeX。右側應出現 IEEE 兩欄、英文題目與 1–6 節／Appendices。這只是草稿版型，不表示已符合某特定會議全部投稿要求。[IEEE 官方範本清單](https://www.overleaf.com/org/ieee)
4. 在 `main.tex` 改兩位作者姓名、學校、系所與 email；摘要和 Keywords 等結果到齊後再填。不要把原截圖中的他人姓名、學校或文字帶進本專案。

若 ZIP 上傳失敗，可改用 **New Project → Blank Project**：把本地 [main.tex](../Overleaf_IEEE/main.tex) 與 [references.bib](../Overleaf_IEEE/references.bib) 的內容分別複製到同名檔案，再在左側建立 `sections` 資料夾，依 [本地 sections 清單](../Overleaf_IEEE/sections/) 建同名 `.tex` 並貼入內容。所有 `\input{sections/...}` 指向的檔案都要存在，才按 Recompile；ZIP 上傳可避免逐檔建立。

## 邀請組員一起編輯

按右上 **Share** → 輸入組員的 Overleaf 帳號 email → 權限選 **Can edit** → **Invite**。也可開啟 edit link sharing，但拿到編輯連結且有 Overleaf 帳號的人可加入；若只給指定組員，email 邀請較清楚。免費方案的專案擁有者目前可有 **1 位 collaborator**，正好符合兩人共編；若畫面顯示額度不足，先確認專案既有邀請與學校方案。[Overleaf 分享說明](https://docs.overleaf.com/collaborating/sharing-a-project)、[方案限制](https://www.overleaf.com/user/subscription/plans)

## 分工與排版

- 兩人各編 [共同分工](./論文_共同Phase排程與分工.md)指定的 `sections/NN_NN_*.tex`。每個小節一檔，減少同時改同一行；`main.tex` 放章節順序、題目、作者與 Abstract。
- 寫段落用普通英文文字；百分號須寫 `\%`，底線寫 `\_`。引用文獻用 `\cite{archhc2022}` 等 BibTeX key，圖表用 `\label{fig:...}` 及 `Fig.~\ref{fig:...}`。新增 `figure`／`table` 時讓 LaTeX 自動編號，不要手打「Fig. 7」。
- 圖成品以 PDF／PNG 上傳 `figures/`，在相應小節用 `\includegraphics[width=\columnwidth]{figures/name.pdf}`；圖說在圖下、表題在表上。寬圖只有必要時用 `figure*` 跨兩欄。[IEEE 會議範本說明](https://www.overleaf.com/latex/templates/ieee-conference-template/grfzhhncsfqn)
- 每完成一小節按 Recompile 看錯誤。Overleaf 可共同即時編輯；稿件的版本以專案 History 管理，本地 GitHub 只保留模板、分工與原始實驗證據，不需維持 personA/personB 稿件資料夾。

## 已回收的單 block 數值

`main.tex` 與 5.3 仍是待撰寫模板，**數據已完成**。新版專案 ZIP 內的 `data/V012_single_block_10ns.csv` 是三版主表的唯讀副本，兩位作者在 Overleaf 都能查看；完整證據留在本地 [結果資料夾](../工作站結果/單block正式週期/)。若 Overleaf 專案已在本次更新前建立，將該 CSV 單獨上傳到專案的 `data/`，不必重建專案。A 在 4.4、5.3、R7、F8 使用主表：V0/V1/V2 的 135-byte `N_single` 皆為 258，單 block throughput 皆為 0.418604651 Gbps。不要從舊 CSV 複製 240-cycle 或 4096-byte P/T。B 寫摘要時引用 A 已完成的比較與限制。
