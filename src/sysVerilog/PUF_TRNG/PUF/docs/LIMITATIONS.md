# 範圍與限制

- 尚未進行真正斷電冷啟動、受控溫度/電壓及長期老化測試；bitstream reload與abort/reset不等於斷電。
- 每板專屬bitmap的1000次成功，是當時實驗室條件下的重現性，不是所有條件的保證。
- 共同bitmap第二板49/111次WEAK_PAIR拒絕，可靠度目標未通過。它表示量測不可靠，不表示偽造硬體；不同板也可能通過margin。
- 兩板72/256bit差異只證明這次兩板輸出不同，不足以估計族群唯一性、熵或安全強度。不能宣稱256-bit輸出等於256-bit安全。
- Registration沒有先前helper可修正，輸出五次投票後的參考；重建每16bit區塊的SECDED可修1bit/偵測2bit，3bit以上可能誤接受。實板千次中修正數為0，不是ECC修復能力的實板證明；錯誤注入能力由模擬驗證。
- 本核心沒有MAC/簽章/參考hash驗證。錯誤helper、不同bitmap或多bit錯誤不保證被拒絕。外部資料完整性與身份認證由整體系統處理。
- 沒有SHA3 adapter或SHA3串接測試；未提供ASIC實體RO、製程庫或ASIC物理signoff。
- 新DC入口尚待學校DC/library實跑；本地Verilator通過不代表VCS/DC通過。原FPGA成功不代表重新整合後不需重新查timing/CDC。
- 當前constraints依賴640RO/特定hierarchy/PYNQ-Z2，其他板型/更改pair數不能只改參數而不重新設計約束與介面。
