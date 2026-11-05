#!/usr/bin/env bash
# Wide baud hunt: catch a servo left at a non-standard rate by a stray EEPROM write.
# Only prints the rates that ANSWER, so a hit is impossible to miss.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"
source "$HOME/miniforge/etc/profile.d/conda.sh" 2>/dev/null
conda activate lerobot 2>/dev/null
PY=$(command -v python3)

echo "device: $(ls /dev/ttyACM* 2>&1)"
hits=0
for B in 2400 4800 7200 9600 14400 19200 28800 38400 57600 76800 115200 128000 153600 \
         200000 250000 460800 500000 921600 1000000 1500000 2000000; do
  out=$(timeout 30 "$PY" "$T/servo_bus_ping.py" --port /dev/ttyACM0 --baud "$B" --max-id 1 --repeat 5 2>&1)
  if echo "$out" | grep -qE "id +1: answered [1-9]"; then
    echo "  HIT  $B baud -> $(echo "$out" | grep -E 'id +1: answered')"
    hits=$((hits + 1))
  fi
done

if [ "$hits" -eq 0 ]; then
  echo "no hit at any of the 21 rates tried (2400 .. 2 Mbaud)"
else
  echo "$hits rate(s) answered"
fi
