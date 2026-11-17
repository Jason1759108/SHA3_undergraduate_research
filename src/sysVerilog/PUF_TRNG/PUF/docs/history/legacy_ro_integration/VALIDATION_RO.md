# RO 整合驗證

日期：2026-11-05（Asia/Taipei）。工具：Windows x86-64、Verilator 5.38、Zig 0.16.0。

已部署到指定 src/puf，並從該目錄實際執行 run_local.ps1 -Mode all；wave/count/ro/ecc 四組重新編譯及模擬全部通過。使用者原 Makefile、PATTERN_PUF、syn.tcl 的內容保持不變。修改前檔案已完整保存於聊天工作區 work/puf_ro_original。

## 實際通過

- wave：預設 TESTBED_PUF 走人工延遲 RO waveform → 選擇／reset／穩定等待 → 真實 Counter → PUF → ECC。
- 10 個完整流程 checkpoint 通過；8 次完整 1280 筆量測操作、2 次弱／停振拒絕操作，各 5 筆量測。
- Registration 與 Certification 比對獨立的 GOLD/ALT 原始資料、helper。
- 每筆量測依 1000ns 視窗與模型 RO 週期計算預期 count，實測差異在 ±2；沒有以人工 count 模型代替。
- 選擇只能在 Counter reset 中改變、只同時 enable 兩路、只請求 Bitmap 選中的配對、順序遞增、每組重複五次。
- 結果背壓保持、reset 後重建、16 個分散位元修正、同區塊雙錯誤拒絕。
- 相同頻率與停振均 PUF_WEAK_PAIR；停振不會成為可靠 PUF bit。
- 另一份 Bitmap 覆蓋最後候選；量測途中 reset 後恢復。
- count：保留原 PATTERN_PUF 的 21 個 checkpoint，含無效命令、缺 helper、錯誤 Bitmap、量測 timeout、三錯誤已知限制；全部通過。
- ro：11 次 Counter 單元量測，含 8-bit wrap、停振、reset；新增 RO-domain reset release 同步後仍通過。
- ecc：4 clean、64 single、480 double 案例通過。
- 四份 manifest 在乾淨目錄無 generated include、無指定 top、無 MULTITOP waiver，編譯通過。
- physical RTL template 僅做語法／elaboration lint；為刻意的回授迴路關閉 UNOPTFLAT 警告。**沒有執行零延遲環形電路模擬，沒有以此宣稱硬體振盪已驗證。**

wave 虛擬時間約 12ms；active-pair 模型在本機約 5 秒完成模擬。第一版 640-process 模型亦通過，但較慢；優化後的十筆結果 checkpoint 與第一版一致。

## 沒有驗證的範圍

本機沒有 VCS/DC、學校製程庫或實體板。未完成 mapped netlist、實體 RO primitive/cell mapping、佈局繞線、時序／clock mux／Gray skew／reset signoff、實際跨晶片熵或 PVT 實測。結構 RO 是可替換模板，模型 seed 不是硬體熵。

保留使用者自訂 Makefile、PATTERN_PUF、原 SHA3 syn.tcl；新增專用 Makefile.ro、syn_puf_ro.tcl 及 manifests。原 syn.tcl 仍不能當作 PUF 合成入口。

未加入 SHA3、金鑰擷取或身分認證。SECDED 超出每區塊一錯誤能力時可能誤解碼，舊 count Pattern 的 LIMIT 測試維持不變。
