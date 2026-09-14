#!/bin/bash

# ==================== 請依據您的硬體設計修改以下參數 ====================
CYCLES_PER_BLOCK=480   # 處理一個 block 需要的 clock cycles 數 (請依您 IP 的實際數值修改)
BITS_PER_BLOCK=1088   # SHA3-256 的 Rate (預設為 1088 bits)
# ====================================================================

PERIODS=$(seq 100.0 -1.0 1.0)

mkdir -p sweep_results
CSV_LOG="sweep_results/sweep_summary.csv"

# 寫入 CSV 表頭
echo "Period(ns),Slack,Total_Power(mW),Throughput(Mbps),Energy_per_bit(pJ/bit)" > $CSV_LOG

for PERIOD in $PERIODS; do
    FORMATTED_PERIOD=$(printf "%.1f" $PERIOD)
    
    echo "------------------------------------------------"
    echo " 🚀 開始合成週期: ${FORMATTED_PERIOD} ns"
    echo "------------------------------------------------"

    export CLK_PERIOD=$FORMATTED_PERIOD
    
    # 執行 DC 合成
    ./01_run_dc 2>&1 | tee dc_run.log
    
    DEST_DIR="sweep_results/period_${FORMATTED_PERIOD}"
    mkdir -p "$DEST_DIR"
    
    # 備份報告
    cp -r ./Report/* "$DEST_DIR/" 2>/dev/null
    cp dc_run.log "$DEST_DIR/"
    
    # 1. 抓取 Slack 數值
    SLACK_VAL=$(grep -i "slack" $DEST_DIR/SHA3.timing | head -n 1 | awk '{print $NF}')
    if [ -z "$SLACK_VAL" ]; then SLACK_VAL="N/A"; fi

    # 2. 抓取 Total Power 數值 (從 SHA3.power 的最後一行提取 Total Power)
    POWER_VAL=$(grep -A 10 "Power Group" $DEST_DIR/SHA3.power | grep "Total" | awk '{
        # 判斷單位是 mW 還是 uW 並統一換算為 mW
        val = $(NF-1);
        unit = $NF;
        if (unit == "uW") { print val / 1000.0 }
        else if (unit == "mW") { print val }
        else if (unit == "W") { print val * 1000.0 }
        else { print val }
    }')
    if [ -z "$POWER_VAL" ]; then POWER_VAL="0"; fi


    # 3. 用 Linux 內建的 AWK 工具進行小數點計算
    CALC_RESULT=$(awk -v p="$POWER_VAL" -v t="$FORMATTED_PERIOD" -v c="$CYCLES_PER_BLOCK" -v b="$BITS_PER_BLOCK" 'BEGIN {
        if (p > 0 && t > 0) {
            tp = (b / (c * t)) * 1000
            energy = (p * t * c) / b
            printf "%.2f,%.3f\n", tp, energy
        } else {
            printf "N/A,N/A\n"
        }
    }')

    TP_VAL=$(echo $CALC_RESULT | cut -d',' -f1)
    ENERGY_VAL=$(echo $CALC_RESULT | cut -d',' -f2)

    # 4. 印出單次結果並存入 CSV
    echo "   [RESULT] Period: ${FORMATTED_PERIOD}ns | Slack: ${SLACK_VAL} | Power: ${POWER_VAL}mW | TP: ${TP_VAL}Mbps | Energy: ${ENERGY_VAL}pJ/bit"
    echo "${FORMATTED_PERIOD},${SLACK_VAL},${POWER_VAL},${TP_VAL},${ENERGY_VAL}" >> $CSV_LOG
    
    echo "週期 ${FORMATTED_PERIOD} ns 完成。"
done

echo "所有掃描測試完畢！結果已匯出至 $CSV_LOG"