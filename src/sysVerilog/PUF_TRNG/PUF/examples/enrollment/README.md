# 每板註冊資料

真正的資料由 `board_validation.run_validation()` 在板端建立 `results_<timestamp>/enrollment.json`，包含bitmap_hex（320bit選256）、helper_hex（80bit）、window_cycles、warmup_cycles、bitstream_sha256、hwh_sha256與format。

不得將任意全零或示例bitmap當成可用值，故此處不提供會被誤用的假key/helper。歷史實驗資料在docs/results，已標明bitstream與板角色；新硬體/新bitstream應重新註冊。重建時載入外部原bitmap/helper，不做新的篩選。
