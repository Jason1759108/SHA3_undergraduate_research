# 健康熵源與 FPGA SHA3 功能整合

這一階段把已通過獨立驗證的 SHA3 與健康監測熵源放進**同一份 FPGA 電路**。`baseline_sources.json` 記錄 19 份 RTL 的來源與 SHA-256，避免把未測過的研究分支混進來。

資料流程為：

```text
8 路 RO → 同步取樣 → 1024 個啟動樣本（丟棄）
                   → 1024 個保留樣本（持續做 RCT/APT）
                   → 只有完整健康批次可讀取 RAM
                   → PS 讀回 1024 bytes，打包到 DDR
                   → DMA → FPGA SHA3-256 → DMA → PS
                   → 與 Python 對相同 raw bytes 的 SHA3 比對
                   → 全部通過才回傳 32-byte 候選輸出
```

PS 是板上 ARM 處理器；DDR 是板上主記憶體；DMA 是直接搬運記憶體資料的控制器。這個版本由 PS 程式串接流程，尚未實作全自動的 RO→SHA3 硬體串流。不可繞過這個程式，另把單獨的 SHA3 診斷介面宣稱為健康把關的亂數輸出。

## 使用方式

給組員的完整成果入口：[已完成驗證、原始證據與交付索引](verification/README.md)。

只需要解壓 `delivery/trng_integrated_ready.zip`，將其中八個檔案上傳到板上同一個新資料夾，依 [直接上板步驟](docs/BOARD_ONLY_STEPS.md) 執行。這次不用操作 Vivado。

發布前數字與保留警告，見 [離線驗證結果](docs/VALIDATION_RESULT.md)。2026-11-16 已完成板號 21600 的 [整合版實板驗收與新布局原始資料評估](captures/board_21600/integrated_20261116/REVIEW.md)：34 次已知訊息、16+1000 批端到端比對、9 組非 IID 估計與 9 組 RO 重啟評估通過。

應用收尾的補充：[6.6 與 7.1 到底代表什麼](docs/ENTROPY_COMPARISON.md)；[SHA3 輸出 SP 800-22 初測實板結果](captures/board_21600/sts_pilot_20261116/REVIEW.md)。3907 批摘要核對正確，單條百萬 bits 的 15 類均適用，188 個子結果中 187 個達門檻，保留 1 個模板 P=0.004706，未宣稱全部通過。這次約五分鐘的應用初測範圍已完成。

| 目錄／檔案 | 用途 |
|---|---|
| rtl/sha3、rtl/health | 凍結的兩組 RTL；使用原本具 parity/replay 的 SHA3 核心 |
| python/TRNG_Integrated_Bringup.ipynb | 直接上板操作、34 次已知訊息比對、16 批整合驗收與 1000 批收集 |
| python/trng_pynq.py | 單一電路載入、健康閘門、摘要核對、故障鎖定及明確復原 |
| python/trng_sha3.py | 136-byte 區塊封包、DMA 傳輸、狀態碼與 32-byte 摘要解碼 |
| python/trng_health.py | 原始熵源狀態檢查；健康失敗時不讀樣本 RAM |
| python/trng_collect.py | 保留每批 raw、摘要、健康狀態，打包 ZIP 與統計工具輸入檔 |
| sim | 單元、原本 SHA3 正常／故障修復、AXI、整合系統與 PYNQ 相容性測試 |
| vivado | 可重新產生工程、打包 IP、建置、模擬與實體查核的腳本 |
| build/overlay | 通過發布檢查後的配對八檔；完整工作工程不納入 Git |
| docs | 功能、接線、驗證範圍與上板說明 |

## 能證明與仍待完成的事

離線模擬與 PYNQ 模擬測試的範圍見驗證文件；本次另以使用者回傳的原始 ZIP 與執行紀錄完成實板核對。共 1016 批摘要在本機對 raw 再次重算 SHA3，全部相符，結束時 RO 關閉、兩通道 DMA 停止。原始檔、指紋與工具原始輸出保留於 captures。

現在可稱為「有健康監測與 FPGA SHA3 的 TRNG 功能原型」。正式可用的熵信用、輸出量依據、不同環境／電壓／溫度與不同板卡下的穩健性、用途要求的驗證，以及低功耗與效能量測仍需另外完成。SHA3 不會創造原始資料缺少的熵。每次輸出長度為 256 bits，不等於已證明有 256 bits 真實熵。

舊健康來源保留值 **6.638383 bits／八路樣本**屬於 stage3。新布局以本次 1,024,000 個原始八路樣本重新評估，綜合保留估計為 **7.092671 bits／八路樣本**，最低單路為 **0.741531 bits／單路樣本**。這些是本板、本版、本次資料的統計結果，不是正式熵信用，也不能推論 SHA3 增加了物理熵。
