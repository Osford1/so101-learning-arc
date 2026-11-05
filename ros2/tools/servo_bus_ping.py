#!/usr/bin/env python3
"""
servo_bus_ping.py — ping every servo address on a Feetech/SCS bus, protocol 1.0.

Dependency-light (pyserial only) on purpose: it runs on Windows against a COM port
as well as inside WSL, which is what lets you tell a *hardware* fault apart from
a *USB/IP* fault when the arm is passed through to a VM.

    # inside WSL (arm forwarded with usbipd)
    python3 servo_bus_ping.py --port /dev/ttyACM0

    # native Windows (arm NOT forwarded) — COM port from `usbipd list` / Device Manager
    python servo_bus_ping.py --port COM<n>

Feetech protocol 1.0 PING packet:  FF FF <id> 02 01 <checksum>
Response:                          FF FF <id> <len> <err> <params...> <checksum>

Read-only: a ping never changes a servo's state.
"""

from __future__ import annotations

import argparse
import sys
import time

try:
    import serial  # pyserial
except ImportError:
    sys.exit("pyserial is required:  pip install pyserial")

PING = 0x01
BROADCAST = 0xFE


def checksum(body: list[int]) -> int:
    return (~sum(body)) & 0xFF


def ping(ser: "serial.Serial", servo_id: int, timeout: float = 0.05) -> bytes | None:
    body = [servo_id, 0x02, PING]
    packet = bytes([0xFF, 0xFF, *body, checksum(body)])
    ser.reset_input_buffer()
    ser.write(packet)
    ser.flush()
    deadline = time.monotonic() + timeout
    buf = bytearray()
    while time.monotonic() < deadline:
        chunk = ser.read(32)
        if chunk:
            buf.extend(chunk)
            if len(buf) >= 6 and buf[0] == 0xFF and buf[1] == 0xFF:
                return bytes(buf)
    return bytes(buf) if buf else None


def parse_frame(buf: bytes):
    """Locate a protocol-1.0 status frame and validate its checksum.

    Frame: FF FF <id> <len> <err> [params] <chk> with chk = ~(id+len+err+params) & 0xFF.
    Returns (servo_id, err, checksum_valid) or None. A reply that arrives with a corrupted
    checksum is as diagnostic as a missing one: it means the wire, not the protocol.
    """
    for i in range(max(0, len(buf) - 3)):
        if buf[i] == 0xFF and buf[i + 1] == 0xFF:
            servo_id, length = buf[i + 2], buf[i + 3]
            chk_index = i + 3 + length
            if chk_index >= len(buf):
                return (servo_id, None, False)
            body = buf[i + 2 : chk_index]
            valid = ((~sum(body)) & 0xFF) == buf[chk_index]
            err = buf[i + 4] if length >= 2 and i + 4 < chk_index else None
            return (servo_id, err, valid)
    return None


def scan(port: str, baud: int, max_id: int, verbose: bool, repeat: int = 3, quiet: bool = False) -> dict[int, bytes]:
    """Ping every id `repeat` times and report a HIT RATE per id.

    Repeating matters: a marginal connection answers some fraction of the time, and a
    single ping per id per baudrate reports such a bus as 'nothing answered' — a false
    negative that sends you chasing a fault that isn't where you think it is.

    Checksums matter too: 'answered 2/5' and 'answered 2/5, 2 checksum-valid' are very
    different diagnoses (marginal wire vs an id/baud mismatch).
    """
    hits: dict[int, int] = {}
    valid_hits: dict[int, int] = {}
    best: dict[int, bytes] = {}
    with serial.Serial(port, baudrate=baud, timeout=0.02, write_timeout=1.0) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        for servo_id in range(1, max_id + 1):
            for _ in range(repeat):
                resp = ping(ser, servo_id)
                if not resp:
                    continue
                frame = parse_frame(resp)
                if frame and frame[0] == servo_id:
                    hits[servo_id] = hits.get(servo_id, 0) + 1
                    if frame[2]:
                        valid_hits[servo_id] = valid_hits.get(servo_id, 0) + 1
                    best.setdefault(servo_id, resp)
                elif verbose and not quiet:
                    print(f"  id {servo_id:>3}: noise len={len(resp)} {resp.hex(' ')}")
    if not quiet:
        for servo_id in sorted(hits):
            v = valid_hits.get(servo_id, 0)
            flag = "" if v == hits[servo_id] else "   <-- CORRUPTED frames on the wire"
            print(f"  id {servo_id:>3}: answered {hits[servo_id]}/{repeat}  checksum-valid {v}/{hits[servo_id]}"
                  f"   raw={best[servo_id].hex(' ')}{flag}")
        missed = [i for i in range(1, max_id + 1) if i not in hits]
        if hits and missed:
            print(f"  no answer from: {missed[0]}..{missed[-1]} ({len(missed)} ids)")
    return best


def watch(port: str, baud: int, max_id: int, seconds: float, passes: int) -> int:
    """Live monitor: print every ID that appears/disappears, so you can reseat a connector
    and see immediately whether it mattered. Re-detects the port each pass (a replug can
    change the COM number)."""
    print(f"== LIVE WATCH on {port} @ {baud} baud for {seconds:.0f}s "
          f"(any id, {passes} pings per id per pass) ==")
    print("   move/reseat ONE connector at a time and watch which ids come and go\n")
    prev: set[int] = set()
    t0 = time.monotonic()
    while time.monotonic() - t0 < seconds:
        stamp = f"{time.monotonic() - t0:6.1f}s"
        try:
            dev = detect_port() if port in ("auto", "AUTO") else port
            found = set(scan(dev, baud, max_id, verbose=False, repeat=passes, quiet=True))
        except (serial.SerialException, SystemExit) as exc:
            print(f"[{stamp}] port unavailable: {type(exc).__name__}: {exc}")
            time.sleep(1.0)
            continue
        appeared, gone = sorted(found - prev), sorted(prev - found)
        if appeared:
            print(f"[{stamp}] + APPEARED: {appeared}   (now: {sorted(found)})")
        if gone:
            print(f"[{stamp}] - GONE:     {gone}       (now: {sorted(found)})")
        if not found and prev:
            print(f"[{stamp}] ... bus silent")
        if not appeared and not gone:
            print(f"[{stamp}]   stable: {sorted(found) if found else 'nothing'}")
        prev = found
    print(f"\n== watch finished. ids answering at the end: {sorted(prev)} ==")
    return 0 if prev else 1


def dump_id(port: str, baud: int, servo_id: int, window: float = 0.3) -> int:
    """Ping one id and print EVERY byte that comes back in a long window.

    This is the collision test: if several servos share one id, their replies overlap and
    show up as extra/garbled bytes *after* the first clean packet — which a normal scan
    (that returns as soon as it sees a valid header) would hide.
    """
    print(f"== collision test: id {servo_id} on {port} @ {baud} baud, {window * 1000:.0f} ms window ==")
    body = [servo_id, 0x02, PING]
    packet = bytes([0xFF, 0xFF, *body, checksum(body)])
    with serial.Serial(port, baudrate=baud, timeout=0.01, write_timeout=1.0) as ser:
        for trial in range(5):
            ser.reset_input_buffer()
            t0 = time.monotonic()
            ser.write(packet)
            ser.flush()
            buf = bytearray()
            while time.monotonic() - t0 < window:
                chunk = ser.read(64)
                if chunk:
                    buf.extend(chunk)
            print(f"  trial {trial + 1}: {len(buf):>3} bytes  {buf.hex(' ')}")
    print("\n  1 packet per trial (6 bytes)  -> exactly ONE servo is answering this id")
    print("  ~2x or more bytes / garbage   -> several servos share this id (never re-IDd)")
    return 0


def detect_port() -> str:
    """Find the Feetech adapter's COM port on Windows (VID 1a86 = CH340/CH343)."""
    from serial.tools import list_ports

    candidates = []
    for p in list_ports.comports():
        desc = f"{p.description or ''} {p.hwid or ''}"
        if (p.vid == 0x1A86) or ("CH34" in desc.upper()) or ("USB-SERIAL" in desc.upper()):
            candidates.append(p.device)
    print(f"  (auto-detect: {[p.device for p in list_ports.comports()]} -> {candidates})")
    if not candidates:
        sys.exit("no CH34x/Feetech serial port found — is the arm's USB cable connected?")
    return candidates[0]


def main() -> int:
    # Keep output line-buffered even when redirected to a file, so a backgrounded
    # `--watch` run produces a readable trace WHILE it runs, not only at exit.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", default="auto", help="/dev/ttyACM0 (WSL), COM<n> (Windows), or 'auto'")
    ap.add_argument("--baud", type=int, default=1_000_000)
    ap.add_argument("--also-try-bauds", action="store_true", help="keep trying slower baudrates if nothing answers")
    ap.add_argument("--max-id", type=int, default=20)
    ap.add_argument("--repeat", type=int, default=3, help="pings per id (default 3): a marginal bus answers only some of the time")
    ap.add_argument("--watch", type=float, default=0.0, help="live monitor for N seconds: print ids appearing/disappearing")
    ap.add_argument("--dump-id", type=int, default=0, help="ping this id and print every byte in a 300 ms window (collision test)")
    ap.add_argument("--verbose", action="store_true", help="print non-matching bytes too")
    args = ap.parse_args()
    if args.port in ("auto", "AUTO") and args.watch <= 0 and args.dump_id == 0:
        args.port = detect_port()

    if args.dump_id:
        return dump_id(args.port if args.port not in ("auto", "AUTO") else detect_port(),
                       args.baud, args.dump_id)
    if args.watch > 0:
        return watch(args.port, args.baud, args.max_id, args.watch, max(args.repeat, 2))

    bauds = [args.baud] + ([500_000, 250_000, 115_200, 57_600] if args.also_try_bauds else [])
    for baud in bauds:
        print(f"== {args.port} @ {baud} baud ==")
        try:
            found = scan(args.port, baud, args.max_id, args.verbose, args.repeat)
        except serial.SerialException as exc:
            print(f"  cannot open {args.port}: {exc}")
            print("  (on Windows this often means the port is still forwarded to WSL — `usbipd detach` first)")
            continue
        if found:
            print(f"\nRESULT: {len(found)} servo(s) answered at {baud} baud: {sorted(found)}")
            return 0
        print("  nothing answered\n")
    print("RESULT: no servo answered. The adapter/enumeration may be fine while the servo side is not —")
    print("  check, in this order: 12 V PSU actually on -> servo LEDs lit -> 3-pin chain seated at the")
    print("  controller board and motor 1 -> each hop of the chain (they are in series).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
