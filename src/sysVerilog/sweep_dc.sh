#!/usr/bin/env bash

set -uo pipefail

DESIGN="${DESIGN:-SHA3}"
RUN_SCRIPT="${RUN_SCRIPT:-./01_run_dc}"
REPORT_DIR="${REPORT_DIR:-./Report}"
OUTPUT_ROOT="${OUTPUT_ROOT:-./sweep_results}"
BLOCK_SIZE_BITS=1088

usage() {
    cat <<'EOF'
Usage:
  ./sweep_dc.sh
  ./sweep_dc.sh <start_period_ns> <end_period_ns> <step_ns> <clock_cycles_per_block>

Examples:
  ./sweep_dc.sh 10 2 0.5 120
  ./sweep_dc.sh 1 5 0.25 120
EOF
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

is_positive_number() {
    local value="$1"
    [[ "$value" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$ ]] &&
        awk -v value="$value" 'BEGIN { exit !(value > 0) }'
}

is_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

extract_area() {
    local report="$1"
    awk '
        tolower($0) ~ /total cell area[[:space:]]*:/ {
            value = $NF
            gsub(/,/, "", value)
            print value
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$report"
}

extract_power_mw() {
    local label="$1"
    local report="$2"

    awk -v label="$label" '
        BEGIN { IGNORECASE = 1 }
        index(tolower($0), tolower(label)) {
            value = ""
            unit = ""

            for (i = 1; i <= NF; i++) {
                if ($i == "=" && i + 2 <= NF) {
                    value = $(i + 1)
                    unit = $(i + 2)
                    break
                }
            }

            gsub(/,/, "", value)
            gsub(/[^A-Za-z]/, "", unit)
            unit = tolower(unit)

            if (value !~ /[0-9]/) exit 1

            if      (unit == "w")  scale = 1000.0
            else if (unit == "mw") scale = 1.0
            else if (unit == "uw") scale = 0.001
            else if (unit == "nw") scale = 0.000001
            else if (unit == "pw") scale = 0.000000001
            else exit 1

            printf "%.9g\n", value * scale
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$report"
}

extract_worst_slack() {
    local report="$1"

    awk '
        tolower($1) == "slack" && $2 ~ /^\(/ {
            value = $NF
            gsub(/,/, "", value)

            if (value !~ /[0-9]/) exit 1

            print value
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$report"
}

if [[ $# -eq 0 ]]; then
    read -r -p "Initial clock period (ns): " START_PERIOD
    read -r -p "Final clock period (ns):   " END_PERIOD
    read -r -p "Sweep step (ns):           " STEP
    read -r -p "Clock cycles per block:     " CLOCK_CYCLES_PER_BLOCK
elif [[ $# -eq 4 ]]; then
    START_PERIOD="$1"
    END_PERIOD="$2"
    STEP="$3"
    CLOCK_CYCLES_PER_BLOCK="$4"
else
    usage
    exit 2
fi

is_positive_number "$START_PERIOD" || die "Initial clock period must be a positive number."
is_positive_number "$END_PERIOD"   || die "Final clock period must be a positive number."
is_positive_number "$STEP"         || die "Sweep step must be a positive number."
is_positive_integer "$CLOCK_CYCLES_PER_BLOCK" || \
    die "Clock cycles per block must be a positive integer."

[[ -f "$RUN_SCRIPT" ]] || die "Cannot find synthesis command: $RUN_SCRIPT"
[[ -x "$RUN_SCRIPT" ]] || die "$RUN_SCRIPT is not executable. Run: chmod +x $RUN_SCRIPT"

period_text=$(awk -v start="$START_PERIOD" -v finish="$END_PERIOD" -v step="$STEP" '
    BEGIN {
        direction = (start <= finish) ? 1 : -1
        epsilon = step / 1000000.0

        for (count = 0; count < 10000; count++) {
            value = start + direction * count * step

            if (direction > 0 && value > finish + epsilon) break
            if (direction < 0 && value < finish - epsilon) break

            printf "%.9g\n", value
        }

        if (count == 10000) exit 2
    }
') || die "Sweep would require 10000 or more synthesis runs."

mapfile -t PERIODS <<< "$period_text"
((${#PERIODS[@]} > 0)) || die "No clock periods were generated."

timestamp=$(date +%Y%m%d_%H%M%S)
run_root="$OUTPUT_ROOT/sweep_$timestamp"
csv_file="$run_root/sweep_summary.csv"

mkdir -p "$run_root"
printf '%s\n' \
    'clock_period_ns,clock_cycles_per_block,block_size_bits,total_cell_area,static_power_mw,dynamic_power_mw,total_power_mw,throughput_gbps,energy_per_bit_pj,worst_slack_ns,status' \
    > "$csv_file"

echo "============================================================"
echo "DC clock sweep"
echo "  Start : $START_PERIOD ns"
echo "  End   : $END_PERIOD ns"
echo "  Step  : $STEP ns"
echo "  Cycles/block : $CLOCK_CYCLES_PER_BLOCK"
echo "  Block size   : $BLOCK_SIZE_BITS bits"
echo "  Runs  : ${#PERIODS[@]}"
echo "  CSV   : $csv_file"
echo "============================================================"

for period in "${PERIODS[@]}"; do
    period_tag=${period//./p}
    run_dir="$run_root/period_${period_tag}ns"
    marker="$run_dir/.synthesis_started"
    log_file="$run_dir/dc_run.log"

    mkdir -p "$run_dir/Report"
    : > "$marker"

    echo
    echo "[RUN] Clock period = $period ns"
    export CLK_PERIOD="$period"

    "$RUN_SCRIPT" 2>&1 | tee "$log_file"
    dc_status=${PIPESTATUS[0]}

    if [[ -d "$REPORT_DIR" ]]; then
        cp -a "$REPORT_DIR/." "$run_dir/Report/"
    fi

    area_report="$REPORT_DIR/$DESIGN.area"
    power_report="$REPORT_DIR/$DESIGN.power"
    timing_report="$REPORT_DIR/$DESIGN.timing"

    area="N/A"
    static_power="N/A"
    dynamic_power="N/A"
    total_power="N/A"
    throughput=$(awk -v bits="$BLOCK_SIZE_BITS" -v cycles="$CLOCK_CYCLES_PER_BLOCK" \
        -v period="$period" 'BEGIN { printf "%.9g\n", bits / (cycles * period) }')
    energy_per_bit="N/A"
    worst_slack="N/A"
    status="OK"

    if ((dc_status != 0)); then
        status="DC_FAILED"
    elif [[ ! -s "$area_report" || ! "$area_report" -nt "$marker" ||
            ! -s "$power_report" || ! "$power_report" -nt "$marker" ||
            ! -s "$timing_report" || ! "$timing_report" -nt "$marker" ]]; then
        status="REPORT_MISSING"
    else
        area=$(extract_area "$area_report" 2>/dev/null || true)
        static_power=$(extract_power_mw "Cell Leakage Power" "$power_report" 2>/dev/null || true)
        dynamic_power=$(extract_power_mw "Total Dynamic Power" "$power_report" 2>/dev/null || true)
        worst_slack=$(extract_worst_slack "$timing_report" 2>/dev/null || true)

        area=${area:-N/A}
        static_power=${static_power:-N/A}
        dynamic_power=${dynamic_power:-N/A}
        worst_slack=${worst_slack:-N/A}

        if [[ "$static_power" != "N/A" && "$dynamic_power" != "N/A" ]]; then
            total_power=$(awk -v static="$static_power" -v dynamic="$dynamic_power" \
                'BEGIN { printf "%.9g\n", static + dynamic }')
            energy_per_bit=$(awk -v power="$total_power" -v rate="$throughput" \
                'BEGIN { printf "%.9g\n", power / rate }')
        fi

        if [[ "$area" == "N/A" || "$static_power" == "N/A" ||
              "$dynamic_power" == "N/A" || "$total_power" == "N/A" ||
              "$energy_per_bit" == "N/A" ||
              "$worst_slack" == "N/A" ]]; then
            status="PARSE_FAILED"
        elif awk -v slack="$worst_slack" 'BEGIN { exit !(slack < 0) }'; then
            status="TIMING_FAILED"
        fi
    fi

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$period" "$CLOCK_CYCLES_PER_BLOCK" "$BLOCK_SIZE_BITS" "$area" \
        "$static_power" "$dynamic_power" "$total_power" "$throughput" \
        "$energy_per_bit" "$worst_slack" "$status" \
        >> "$csv_file"

    echo "[RESULT] period=${period}ns cycles/block=${CLOCK_CYCLES_PER_BLOCK} area=${area} static=${static_power}mW dynamic=${dynamic_power}mW total=${total_power}mW throughput=${throughput}Gbps energy/bit=${energy_per_bit}pJ/bit slack=${worst_slack}ns status=${status}"
done

cp "$csv_file" "$OUTPUT_ROOT/latest_summary.csv"

echo
echo "============================================================"
echo "Sweep finished"
echo "CSV: $csv_file"
echo "Latest copy: $OUTPUT_ROOT/latest_summary.csv"
echo "============================================================"

if command -v column >/dev/null 2>&1; then
    column -s, -t "$csv_file"
else
    cat "$csv_file"
fi
