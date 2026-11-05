#!/usr/bin/env bash
# Verify the servo is back to a clean factory-ish state: baud index 0, return delay 0, id 1.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"
source "$HOME/miniforge/etc/profile.d/conda.sh" 2>/dev/null
conda activate lerobot 2>/dev/null
PY=$(command -v python3)

echo "=== reads at 1 Mbaud (retried internally, link is ~27%) ==="
for R in "6 baud index" "7 return delay" "5 id" "3 model(2B)"; do
  ADDR=${R%% *}
  LABEL=${R#* }
  printf "  reg %-2s %-14s -> " "$ADDR" "$LABEL"
  "$PY" "$T/servo_regs.py" --port /dev/ttyACM0 --expected-id 1 read "$ADDR" 2>&1 | tail -1
done

echo
echo "=== bus quality at 1 Mbaud (healthy = ~40/40) ==="
"$PY" "$T/bus_health.py" --port /dev/ttyACM0 --tries 40 2>&1 | grep -E "PING|READ|model|VERDICT"
