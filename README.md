在工作站上面可以用build [名稱]來創建我們熟悉的有00 01 02 03的資料夾
1. 先用build sha3_pkg
2. 進到../sha3_pkg/01_RTL/sha3_pkg.sv貼上github上的檔案
3. 創建任何需要import pkg的區塊時，一樣先在../ 用build name
4. 在../name/01_RTL/name.sv參考github上test資料夾裡面test.sv的寫法實作
5. 在../name/00_TESTBED/參考github上test資料夾裡面的寫法寫filelist跟需要的PATTERN和TESTBED
6. 然後就可以用我們熟悉的方法跑01，其他還沒研究
