#!/usr/bin/env bash
# Look for the servo everywhere: every baudrate, then a full id scan on the two most likely.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"

# Prefer the LeRobot env's python (it has pyserial); fall back to system python3.
PY=python3
if [ -f "$HOME/miniforge/etc/profile.d/conda.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/miniforge/etc/profile.d/conda.sh"
  conda activate lerobot 2>/dev/null && PY="$(command -v python3)" && echo "using env python: $PY"
fi
"$PY" -c "import serial" 2>/dev/null || { echo "!! no pyserial in $PY — install it or activate the lerobot env"; exit 1; }

echo "=== device present? ==="
ls -l /dev/ttyACM* 2>&1
if ! ls /dev/ttyACM* >/dev/null 2>&1; then
  echo
  echo "!! No /dev/ttyACM* — the arm is NOT attached to this distro, so every scan below"
  echo "   would return nothing. Re-attach on Windows first, then re-run:"
  echo "     powershell -ExecutionPolicy Bypass -File ros2\windows\attach-arm.ps1"
  exit 1
fi
sudo chmod 666 /dev/ttyACM* 2>/dev/null

echo
echo "=== id 1 at every baudrate (6 pings each) ==="
for B in 1000000 500000 250000 128000 115200 57600 38400 19200 9600; do
  printf "%-8s " "$B"
  timeout 40 python3 "$T/servo_bus_ping.py" --port /dev/ttyACM0 --baud "$B" --max-id 1 --repeat 6 2>&1 \
    | grep -E "id +1:|nothing answered" | tr '\n' ' '
  echo
done

echo
echo "=== full scan ids 1..20 @ 1 Mbaud ==="
timeout 90 python3 "$T/servo_bus_ping.py" --port /dev/ttyACM0 --baud 1000000 --repeat 2 2>&1 \
  | grep -E "id +[0-9]+:|RESULT|nothing" | head -6

echo "=== full scan ids 1..20 @ 57600 ==="
timeout 90 python3 "$T/servo_bus_ping.py" --port /dev/ttyACM0 --baud 57600 --repeat 2 2>&1 \
  | grep -E "id +[0-9]+:|RESULT|nothing" | head -6

echo "=== full scan ids 1..20 @ 250000 ==="
timeout 90 python3 "$T/servo_bus_ping.py" --port /dev/ttyACM0 --baud 250000 --repeat 2 2>&1 \
  | grep -E "id +[0-9]+:|RESULT|nothing" | head -6
