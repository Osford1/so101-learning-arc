#!/usr/bin/env python3
"""
bus_health.py — one-command quality report for the Feetech servo bus.

Healthy: ~100% valid frames. This tool exists because "it answers sometimes" is the
symptom that wastes the most time — a link that decodes 30% of frames is NOT working, and
the failure shape tells you which side to suspect:

    python3 bus_health.py --port /dev/ttyACM0      # inside WSL
    python bus_health.py --port COM<n>               # natively on Windows
    python3 bus_health.py --port COM<n> --tries 60   # more samples

Reports, over N exchanges at 1 Mbaud:
  * PING valid      — can I even hear the servo?
  * READ valid      — can I read a register (longer frame, fails sooner on a bad link)
  * failure shapes  — TRUNCATED (lost bytes) / CHECKSUM-BAD (bit error) / GARBAGE (framing lost)
  * model number    — read from register 3, confirms an STS3215 (777) is answering

Read-only. Safe to run any time the arm is powered.
"""

from __future__ import annotations

import argparse
import time

import serial

PING, READ = 0x01, 0x02
ADDR_MODEL = 3


def checksum(body: list[int]) -> int:
    return (~sum(body)) & 0xFF


def frame(servo_id: int, instruction: int, params: list[int]) -> bytes:
    body = [servo_id, len(params) + 2, instruction, *params]
    return bytes([0xFF, 0xFF, *body, checksum(body)])


def classify(buf: bytes) -> tuple[str, bytes]:
    """Return (verdict, valid_frame_bytes_if_any)."""
    for i in range(max(0, len(buf) - 3)):
        if buf[i] == 0xFF and buf[i + 1] == 0xFF:
            length = buf[i + 3]
            chk_index = i + 3 + length
            if chk_index >= len(buf):
                return f"TRUNCATED (got {len(buf) - i} of {length + 4} bytes)", b""
            if ((~sum(buf[i + 2 : chk_index])) & 0xFF) == buf[chk_index]:
                return "VALID", bytes(buf[i : chk_index + 1])
            return "CHECKSUM-BAD (bit error)", b""
    return "GARBAGE (framing lost)", b""


def exchange(ser: "serial.Serial", servo_id: int, instruction: int, params: list[int], window: float):
    ser.reset_input_buffer()
    ser.write(frame(servo_id, instruction, params))
    ser.flush()
    t0 = time.monotonic()
    buf = bytearray()
    while time.monotonic() - t0 < window:
        chunk = ser.read(64)
        if chunk:
            buf.extend(chunk)
    return classify(bytes(buf))


def sweep(ser, servo_id, instruction, params, tries, window):
    tally: dict[str, int] = {}
    valid_frames: list[bytes] = []
    for _ in range(tries):
        verdict, good = exchange(ser, servo_id, instruction, params, window)
        key = verdict.split(" (")[0]
        tally[key] = tally.get(key, 0) + 1
        if good:
            valid_frames.append(good)
    return tally, valid_frames


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", required=True)
    ap.add_argument("--id", type=int, default=1, help="servo id to probe (factory default 1)")
    ap.add_argument("--baud", type=int, default=1_000_000)
    ap.add_argument("--tries", type=int, default=40)
    ap.add_argument("--window", type=float, default=0.08, help="seconds to listen per exchange")
    args = ap.parse_args()

    with serial.Serial(args.port, baudrate=args.baud, timeout=0.02, write_timeout=1.0) as ser:
        time.sleep(0.2)
        p_tally, _ = sweep(ser, args.id, PING, [], args.tries, args.window)
        r_tally, r_frames = sweep(ser, args.id, READ, [ADDR_MODEL, 2], args.tries, args.window)

        p_ok = p_tally.get("VALID", 0)
        r_ok = r_tally.get("VALID", 0)
        print(f"port {args.port} @ {args.baud} baud, id {args.id}, {args.tries} exchanges each")
        print(f"  PING valid {p_ok:>3}/{args.tries}   {p_tally}")
        print(f"  READ valid {r_ok:>3}/{args.tries}   {r_tally}")

        if r_frames:
            params = r_frames[0][5:-1]
            if len(params) >= 2:
                model = params[0] | (params[1] << 8)  # LSB first on these servos
                print(f"  model number from register 3: {model}"
                      f"{'  = STS3215 (expected)' if model == 777 else '  (NOT 777 — unexpected)'}")

        if p_ok >= args.tries * 0.95:
            print("\nVERDICT: bus is healthy.")
            return 0
        if p_ok == 0 and r_ok == 0:
            print("\nVERDICT: nothing is answering. Power, then the cable, then the board.")
            return 2
        print(f"\nVERDICT: MARGINAL — {100 * p_ok / args.tries:.0f}% of pings decode.")
        print("  Failure shapes above name the suspect:")
        print("   * GARBAGE / TRUNCATED dominating  -> lose bytes on the wire: cable, connector,")
        print("     or several servos sharing one id and colliding.")
        print("   * CHECKSUM-BAD dominating         -> bit errors: marginal supply or noise.")
        print("  Test one change at a time and re-run: swap the 3-pin cable, then the servo, then")
        print("  the controller board. Nothing software-side can make 30% into 100%.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
