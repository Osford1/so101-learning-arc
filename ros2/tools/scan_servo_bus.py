#!/usr/bin/env python3
"""
scan_servo_bus.py — which servo IDs actually answer on the Feetech bus?

LeRobot's handshake only probes the 6 IDs its config expects, so "Missing motor IDs 1-6"
is ambiguous: it means *either* the servos are unpowered/unplugged *or* they answer on
other IDs. This scans a wide range of addresses (and several baudrates) and reports what
is really out there.

    python3 scan_servo_bus.py --port /dev/ttyACM0
    python3 scan_servo_bus.py --port /dev/ttyACM0 --baud 1000000 --max-id 20

Read-only: pings only, nothing is written to any servo.
"""

from __future__ import annotations

import argparse
import re
import sys

from lerobot.motors import Motor, MotorNormMode
from lerobot.motors.feetech import FeetechMotorsBus

BAUDS = [1_000_000, 500_000, 250_000, 128_000, 115_200, 57_600]


def scan(port: str, baud: int, max_id: int) -> dict[int, int]:
    """Return {id: model_number} for every address that answers at this baudrate."""
    motors = {f"probe_{i}": Motor(i, "sts3215", MotorNormMode.RANGE_M100_100) for i in range(1, max_id + 1)}
    bus = FeetechMotorsBus(port=port, motors=motors, calibration={})
    bus.default_baudrate = baud
    try:
        bus.connect()  # raises RuntimeError listing what answered vs what it expected
        return {m.id: 777 for m in motors.values()}  # everything answered
    except RuntimeError as exc:
        text = str(exc)
        if "motor check failed" not in text:
            print(f"    (connect failed differently at {baud} baud: {text.splitlines()[0]})")
            return {}
        m = re.search(r"found motor list \(id: model_number\):\s*(\{[^}]*\})", text)
        if not m:
            return {}
        found: dict[int, int] = {}
        for pair in m.group(1).strip("{}").split(","):
            if ":" in pair:
                k, v = pair.split(":")
                found[int(k.strip())] = int(v.strip())
        return found
    except Exception as exc:  # port busy, permission, ...
        print(f"    (scan at {baud} baud failed: {type(exc).__name__}: {exc})")
        return {}
    finally:
        try:
            bus.disconnect()
        except Exception:
            pass


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=None, help="scan only this baudrate")
    ap.add_argument("--max-id", type=int, default=20)
    args = ap.parse_args()

    bauds = [args.baud] if args.baud else BAUDS
    expected = {1: 777, 2: 777, 3: 777, 4: 777, 5: 777, 6: 777}
    results: dict[int, int] = {}
    hit_baud = None

    for baud in bauds:
        print(f"== scanning ids 1..{args.max_id} at {baud} baud ==")
        found = scan(args.port, baud, args.max_id)
        if found:
            print(f"   {len(found)} servo(s) answered: {found}")
            results, hit_baud = found, baud
            break
        print("   nothing answered")

    print()
    if not results:
        print("DIAGNOSIS: no servo answered on ANY address or baudrate.")
        print("  -> The adapter is fine (the port opened), so this is the servo side of the chain:")
        print("     1. Is the arm actually POWERED? Follower = 12 V PSU plugged in at the wall AND")
        print("        into the controller board, switched on. USB alone powers only the adapter chip,")
        print("        not the servos. The STS3215 LEDs light when the servo rail has power.")
        print("     2. Is the 3-pin daisy-chain cable seated at the controller board and at motor 1?")
        print("        One unseated connector kills the whole chain (they are in series).")
        print("     3. Check the chain hop by hop (controller -> 1 -> 2 -> ... -> 6): a broken cable")
        print("        anywhere takes out every servo downstream of it.")
        return 1

    extra = sorted(set(results) - set(expected))
    missing = sorted(set(expected) - set(results))
    print(f"DIAGNOSIS: bus is ALIVE at {hit_baud} baud — {len(results)} servo(s): {sorted(results)}")
    if not missing and not extra:
        print("  -> All six expected IDs (1-6, model 777) are present. The earlier 'missing motors'")
        print("     error was a stale/competing connection (e.g. LeRobot and ros2_control holding the")
        print("     port at the same time) rather than a hardware fault.")
    if missing:
        print(f"  -> Expected IDs NOT answering: {missing}  (check the cable hop before each of these)")
    if extra:
        print(f"  -> IDs answering that the config does not expect: {extra}")
        print("     Those servos need re-ID'ing (one motor on the line at a time), or the config is wrong.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
