#!/usr/bin/env bash
# Restore the servo to factory 1 Mbaud / return-delay 0, retrying until each write lands.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"
export PYTHONPATH="${PYLIBS:-/tmp/pylibs}"
cd "$T" || exit 1

echo "== where is the servo now? =="
python3 bus_health.py --port /dev/ttyACM0 --baud 250000 --tries 12 2>&1 | grep -E "PING|VERDICT" || true

for attempt in 1 2 3 4 5; do
  echo "-- restore attempt $attempt (writing baud index 0 at 250k) --"
  python3 servo_regs.py --port /dev/ttyACM0 --expected-id 1 --baud 250000 write 6 --value 0 2>&1 | tail -2
  sleep 0.5
  if python3 bus_health.py --port /dev/ttyACM0 --tries 8 2>&1 | grep -q "PING valid   [1-9]"; then
    echo "   -> servo answers at 1 Mbaud again"
    break
  fi
done

echo "== final check at 1 Mbaud =="
python3 bus_health.py --port /dev/ttyACM0 --tries 20 2>&1 | grep -E "port|PING|READ|VERDICT"
