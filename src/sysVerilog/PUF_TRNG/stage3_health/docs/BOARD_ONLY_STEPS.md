# 直接上板流程：不需要操作 Vivado

本次使用已在本機完成測試、綜合與實作的健康監測候選版本。你只需要上傳檔案、逐格執行 notebook、下載結果。不用建立專案、打包 IP、接線或產生 bitstream。

## 1. 使用哪一包

資料包：`stage3_health/delivery/entropy_health_ready_20261111.zip`。

在 Windows 解壓縮後，進入 `entropy_health_ready_20261111/board_files`。裡面只有八個要上傳的檔案。ZIP 裡的操作說明與 package_manifest.json 留在電腦，不必上傳。

發布識別：`entropy-health-20261110T172050Z`。這是 UTC 版本時間；操作日期另填實際日期。硬體 ID 是 `0x524F4832`，簡稱 ROH2。

## 2. 八個檔案的用途

| 檔案 | 用途 |
|---|---|
| entropy_health.bit | 設定 FPGA 內的 RO、健康檢測、控制器與記憶體電路 |
| entropy_health.hwh | 描述硬體介面、位址、時脈與參數，供 PYNQ 解析；必須與 bit 配對 |
| entropy_health_pynq.py | 驅動：驗證檔案與設定、啟動/停止擷取，只讀取整批健康檢測通過的資料 |
| analyze_raw.py | 基本原始位元統計的輔助程式 |
| entropy_characterize.py | 每批擷取與保存、分組紀錄、故障/中斷資訊 |
| entropy_campaign.py | 管理 1000 批總流程，核對並匯出聯合/單通道資料與重啟矩陣 |
| Entropy_Health_Bringup.ipynb | 你操作的 notebook，依序做離線檢查、載入、功能驗收、資料復測與打包 |
| release_manifest.json | 六個固定程式/硬體檔案的校驗值，以及本機驗證與實體 RO 紀錄 |

八檔同一資料夾，不與舊 entropy_ro.bit 或 entropy_pynq.py 混用。notebook 可以正常保存執行結果；其他檔案不要手動修改。

## 3. 上傳前

1. 確認是你的板子使用時段，且沒有其他人操作同一張板子。
2. 舊 notebook 若還開著，確認上次 RO 已關閉、結果已下載，再選 **File → Close and Halt**。到 **Running** 確認自己的舊 kernel 已停止。只關閉瀏覽器分頁可能沒有停止 kernel。
3. 在 Jupyter **Files** 首頁按 **New → Folder**，勾選新資料夾後 **Rename**，例如 `entropy_health_113511153`。進入該資料夾。
4. 按 **Upload**，一次選解壓後 board_files 裡的八個檔案；如列表出現待上傳按鈕，再按各列藍色 **Upload**。
5. 確認八個檔名齊全。不必把 ZIP 上傳後期待 Jupyter 自動解壓縮。

## 4. 執行原理

每一批的實際流程：

`啟用 RO → 暖機 → 1024 點啟動健康檢查（不輸出）→ 1024 點正式資料＋持續健康檢查 → RO 關閉 → 整批通過才讀回並存檔`

RCT 是重複次數檢測，偵測同值連續出現過多；APT 是視窗內參考值比例檢測，偵測比例退化。任何一項失敗，這批資料都不能當成有效輸出，驅動不讀取其 RAM。這些檢查是故障監測，不等於證明所有資料不可預測。

目前沒有接 SHA3；目的先確認加上健康監測的新版本是否正常，以及原始資料品質有沒有改變。

## 5. 逐格操作

點開 **Entropy_Health_Bringup.ipynb**。每格點選後按 **Shift+Enter**，等待完成再繼續，先不要 Run All。`In [*]` 表示執行中；出現數字且沒有錯誤才到下一格。

1. **第一個匯入格**：應印 `kernel OK`、PYNQ 與 Python 版本。你原先環境是 PYNQ 2.5 / Python 3.6.5。
2. **第 1 節，離線檢查**：確認 board_id（預設 21600）是實際登記板號，experiment_date 填實際操作日。執行後應通過發布檔檢查。這一格尚未操作 FPGA。
3. **第 2 節，載入電路**：重新設定 FPGA 一次，應依序印 1/4 到 4/4，最後 `RO OFF; ready`。這一格之後先不再重跑。
4. **第 3 節，16 批功能驗收**：應印 HEALTH 1/16 到 16/16。每批欄位應為：

   ```text
   status: 194
   count: 1024
   ro_enable: 0
   fault_mask: 0
   rct_mask: 0
   apt_mask: 0
   observed: 2048
   startup_seen: 1024
   ```

   status=194（十六進位 0xC2）表示完成、啟動檢查通過、整批有效；不是舊版的 status=2。最後應有 `RO OFF confirmed`。

5. **第 4 節，1000 批固定設定復測**：只有第 3 節成功且使用時間足夠才執行。每 16 批為一組，所以 CAPTURE 會從 1/16 重新計數；總進度看 CAMPAIGN，最後應為 `1000/1000`。正常返回：

   ```text
   status: complete
   batches: 1000
   ro_off_confirmed: True
   ```

   本格不重新下載 bitstream。有效取樣與啟動取樣合計約 42 秒，讀回、存檔與後續匯出另外花時間，可能需要數分鐘。過程不要重按 Run 或同時操作其他硬體 notebook。

6. **第 5 節，匯出資料**：只核對和處理檔案，不操作硬體。應有 integrity=PASS、total_samples=1024000、restart_rows=1000、restart_columns=1000。entropy_estimate=null、physical_entropy_certified=false 是預期值；正式資料分析在下載後另做。
7. **第 6 節，打包**：建立 `entropy_health_...zip`，其中含 16 批功能資料、1000 批原始資料、紀錄及匯出檔。
8. **File → Save and Checkpoint** 保存 notebook。回 **Files**，單獨勾選新 ZIP 按 **Download**；再下載有執行輸出的 `Entropy_Health_Bringup.ipynb`。
9. 把這兩個下載檔提供給我分析。確認下載完成後關閉自己的 kernel，依實驗室規則結束使用。

若只完成第 3 節，也能執行第 6 節先打包功能資料；不要因此在別人的時段繼續跑第二段。之後有足夠時段再依新 kernel 流程安排復測。

## 6. 失敗時

- 檔案校驗、ID/參數或載入檢查點失敗：停止，不跳過檢查、不換舊驅動繼續。
- HealthFailure：保留錯誤與 fault.json / 分組紀錄，停止後續硬體格。不要自動清除故障並反覆重跑，也不要刪掉故障批次再補一批。
- 若中斷導致沒有 campaign 變數，保留畫面印出的 Campaign folder 整個資料夾；先提供最後錯誤畫面協助打包，不必重收資料。
- ro_off_confirmed=False、cleanup_error、連簡單 print 都卡住或網站失聯：停止操作並交由管理員確認板子狀態。軟體逾時不能保證中止不回應的硬體讀取。

## 7. 已完成與待完成

已完成：逐樣本 RCT/APT 對照、控制器與實際 PS/AXI 系統模擬、PYNQ 2.5 parser 與錯誤分支、收集/匯出/ZIP 測試、綜合實作、時序與實體 RO 核對。發布的八檔與本機證據相符。

尚待：這份新 bitstream 的實板功能與原始資料評估。本次增加啟動檢查並重新佈局，不能直接沿用舊版約 6.65 bits/八路樣本。沒有在實板注入故障、沒有接 SHA3，也沒有宣稱完成熵認證。監測門檻與保證可用的熵量是不同事情。
