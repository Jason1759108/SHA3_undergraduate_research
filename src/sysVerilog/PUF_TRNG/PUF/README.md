# RO-PUF256：模擬、工作站合成、FPGA 與模組整合

此目錄是獨立 PUF 模組，不依賴 repository 的 SHA3 來源。正式 RTL 採用已在 PYNQ-Z2 上板驗證的版本；2026-11-17 整理目錄與執行入口，沒有修改這十個 RTL 的電路內容。

## 做了什麼、成果是什麼

- 640 個 LUT RO，320 組固定且不共用 RO 的候選配對；外部程式替每板選出 256 組，輸入 320-bit bitmap。
- Registration 產生 256-bit PUF 資料與 80-bit helper；Certification 在此代表「重建」，不是身分認證。
- 真實 RO、/8 分頻、16-bit 飽和計數、Gray CDC、多數決、弱配對拒絕與 SECDED 已整合；有 AXI4-Lite 及原生 RTL 核心介面。
- 各板專屬 bitmap：兩板基準各 111/111 成功，後續固定 1000 次重建各 1000/1000 成功、零拒絕、零身份碼改變、零 ECC 修正。
- 同一 bitmap 比較兩板：身份碼相差 72/256 bit；第二板有 49/111 次 WEAK_PAIR 拒絕，完整保留此負面結果。
- 原 bitstream 已通過 routed timing/CDC/DRC/Gray skew 檢查；234 項 methodology 完成並保留預期 RO 警告。

以上實板結論只對應保存 hash 的原 bitstream 與當時實驗條件。搬移後重新合成/布局繞線的設計需重新檢查與註冊。尚未測斷電、受控溫度/電壓；不包含 SHA3、認證協定、256-bit 熵或安全強度保證。

## 從哪裡開始

|需求|入口|
|---|---|
|先了解模組如何接|[INTEGRATION](docs/INTEGRATION.md)|
|工作站 VCS／本地 Verilator 模擬|[sim/README](sim/README.md)|
|工作站 DC 數位合成|[scripts/synthesis/README](scripts/synthesis/README.md)|
|PYNQ-Z2 完整 FPGA 重建|[FPGA_BUILD](docs/FPGA_BUILD.md)|
|板上篩選、註冊、重建|[software/README](software/README.md)|
|成果、原始證據與限制|[VALIDATION](docs/VALIDATION.md)、[LIMITATIONS](docs/LIMITATIONS.md)|
|舊 00/01/02 搬去哪裡|[DIRECTORY_MAP](docs/DIRECTORY_MAP.md)|

## 目錄

```text
rtl/                  正式可合成 RTL（十檔）
sim/                  三套具名Testbench/Pattern、RO/count模型與執行入口
scripts/vivado/       完整 PYNQ-Z2 建置、RO 約束、board files、部署準備
scripts/synthesis/    新版 DC 數位核心合成入口
software/             PYNQ driver、篩選/註冊/重建與 Notebook 範本
verification/         主機測試、Vivado 報告檢查、離線證據核對
examples/             不含 SHA3 的整合與註冊格式說明
docs/                 正式文件、實驗結果、舊版快照
build/                自動產生，不加入 Git
```

## 快速檢查（此目錄執行）

主機檢查用 Python 3.11+；無第三方 pip 依賴。Python 3.6+ 是板端程式需求，兩者不同。

```sh
python3 verification/check_handoff.py
python3 -m unittest discover -s verification -p 'test_*.py' -v
python3 verification/recheck_evidence.py
cd sim
make vcs-core-count
make vcs-ecc-secded
make vcs-axi-ro
```

VCS、DC、Vivado 需要各自環境與授權；未將 VCS/DC 在本地已執行當成事實。此次目錄整理的實際檢查紀錄見 [HANDOFF_CHECKS](docs/HANDOFF_CHECKS.md)。

原始硬體版本/雜湊見 [SOURCE_MANIFEST](docs/SOURCE_MANIFEST.json)。`.gitignore` 排除工具產物、新產生的板端資料與二進位部署檔；歷史實驗中的身份碼只供實驗重現，不可當成產品秘密。

測試檔名已依範圍改為PUF_AXI_RO／PUF_CORE_COUNT／PUF_ECC_SECDED，完整對照見 [TEST_NAMING](docs/TEST_NAMING.md)。
