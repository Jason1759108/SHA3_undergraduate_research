# PYNQ 操作、配對篩選與重建

板端需要相同目錄的 puf256.bit、puf256.hwh、puf256.py、puf_screening.py、board_validation.py。用 `scripts/vivado/prepare_deployment.py` 產生 `build/board_upload`，Notebook 會自動從 software/notebooks 複製到上傳根目錄；不要只上傳 Notebook 子目錄而漏掉 Python。

## 每板自己的註冊

上傳完成後在 Jupyter 執行 PUF256_Validation.ipynb，或在相同目錄：

```python
from board_validation import run_validation
summary = run_validation()
```

它載入 bitstream，對320組各量測32次reference及128次training，依穩定方向和最差margin選256組，凍結bitmap後再做32次獨立holdout；通過才執行硬體Registration，並測100次重建、1次abort/reset後重建、10次相同bitstream reload後重建。未通過會停止並保留資料，不從同一holdout偷偷換樣。

每板產生自己的 `results_<timestamp>/enrollment.json`。常用輸入是 bitmap_hex/helper_hex/window_cycles/warmup_cycles/bitstream_sha256/hwh_sha256；不要把其他板的註冊資料當通用設定。

## 下次重建

```sh
python3 reconstruct.py --enrollment results_<timestamp>/enrollment.json --bitfile puf256.bit
```

會先核對bit/HWH，載入FPGA，再傳原bitmap/helper重建。程式輸出成功與否、PUF資料hex、修正數；不是驗證對方身份。也可直接使用 `Puf256(overlay.puf256_0).reconstruct(bitmap, helper)`。

## 新的一輪固定1000次測試

先跑各板自己的新baseline，確認通過，然後在板端：

```sh
python3 freeze_1000_input.py --board 20100 --baseline results_<timestamp> --out own_enrollment_20100.json
```

```python
from rebuild_1000 import run_1000
summary = run_1000('20100')
```

第二板用20200；這只是實驗角色標籤，不是永久chip ID。freeze程式只打包本板原註冊輸入與driver hash，不重新產生PUF。run_1000初始載入一次FPGA，固定嘗試1000次，不重新註冊、不換配對、不重試到成功。完整程式來源在本目錄，測試資料與匯出ZIP建立於目前板端工作目錄。

若要使用範例 Notebook，先依自己的註冊資料準備輸入；歷史結果裡的已執行 Notebook不是給新板直接套用的設定。原始證據核對程式目前核對已保存的2026-11-13證據；新的實驗需另保存本次來源、frozen input與source hash。

`cross_board.py` / `characterize_common.py` 是共同bitmap研究流程，需要先由主機 verification/compare_boards.py freeze 產生 common_bitmap/reference 與對應manifest；不是一般註冊入口。首次失敗前綴及後續拒絕都應保存，不能只統計成功。

同板同時只執行一個控制程式，等待結果完成後才做下一筆。不要在測試中換bit/HWH/driver或由其他Notebook操作同IP。
