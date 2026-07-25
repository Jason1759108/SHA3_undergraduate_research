// 1. Package 必須最先編譯 (往上兩層回到家目錄，再進入 sha3_pkg 資料夾)
// 如果你的 sha3_pkg.sv 放在 sha3_pkg/01_RTL/ 底下，請用這行：
../../sha3_pkg/01_RTL/sha3_pkg.sv
// (如果你的 sha3_pkg.sv 是直接放在 sha3_pkg/ 底下，則改為 ../../sha3_pkg/sha3_pkg.sv)

// 2. 接著編譯 Testbench 環境
../00_TESTBED/TESTBED.sv
../00_TESTBED/PATTERN.sv

// 3. 最後編譯你的 RTL 設計檔 (因為它需要呼叫上面的 package)
test.sv