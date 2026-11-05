#!/usr/bin/env python3
"""
servo_regs.py — read and write Feetech STS3215 EEPROM registers directly (SCS protocol 1.0).

Built because LeRobot's `lerobot-setup-motors` cannot configure these servos: its
`_find_single_motor_p0` uses `broadcast_ping()` and requires the status packet to carry a
model number, while these servos answer a unicast ping with `ff ff <id> 02 00 <chk>` —
length 2, no model bytes. So the tool reports "motor was not found" for a servo that is
alive and answering. This does the same job over unicast, with retries and read-back
verification, which a marginal multi-drop bus needs.

    # read-only probe: is a servo there, what model, what id/baud?
    python3 servo_regs.py --port /dev/ttyACM0 --expected-id 1 probe

    # the operation setup-motors would do: give ONE servo (connected alone) a new id
    python3 servo_regs.py --port /dev/ttyACM0 --expected-id 1 set-id 6

    # also set the baudrate index (0 = 1 Mbaud, 1 = 500k, 2 = 250k, 3 = 128k, 4 = 115200, 5 = 57600)
    python3 servo_regs.py --port /dev/ttyACM0 --expected-id 1 set-id 6 --baud-index 0

Register map used (SCS/STS series): 3 model number (2 B, RO) · 5 id · 6 baud index ·
40 torque enable · 55 lock. Writes run with the EEPROM unlocked and re-lock afterwards.
Connect ONE servo at a time — that is the whole point: the bus cannot distinguish servos
that share an id.
"""

from __future__ import annotations

import argparse
import sys
import time

import serial

PING, READ, WRITE = 0x01, 0x02, 0x03
ADDR_MODEL, ADDR_ID, ADDR_BAUD, ADDR_TORQUE, ADDR_LOCK = 3, 5, 6, 40, 55
MODEL_STS3215 = 777


def checksum(body: list[int]) -> int:
    return (~sum(body)) & 0xFF


def frame(servo_id: int, instruction: int, params: list[int]) -> bytes:
    body = [servo_id, len(params) + 2, instruction, *params]
    return bytes([0xFF, 0xFF, *body, checksum(body)])


def read_status(ser: "serial.Serial", expect_id: int, timeout: float = 0.05):
    """Return (servo_id, err, params) for the first well-formed status frame, else None."""
    deadline = time.monotonic() + timeout
    buf = bytearray()
    while time.monotonic() < deadline:
        chunk = ser.read(64)
        if chunk:
            buf.extend(chunk)
        for i in range(max(0, len(buf) - 4)):
            if buf[i] == 0xFF and buf[i + 1] == 0xFF:
                sid, length = buf[i + 2], buf[i + 3]
                chk_index = i + 3 + length
                if chk_index >= len(buf):
                    break
                body = buf[i + 2 : chk_index]
                if ((~sum(body)) & 0xFF) != buf[chk_index]:
                    continue  # corrupt frame: keep looking
                err = buf[i + 4]
                params = list(buf[i + 5 : chk_index])
                return (sid, err, params)
    return None


def txrx(ser: "serial.Serial", servo_id: int, instruction: int, params: list[int], timeout: float = 0.05):
    ser.reset_input_buffer()
    ser.write(frame(servo_id, instruction, params))
    ser.flush()
    return read_status(ser, servo_id, timeout)


def retry(ser, servo_id, instruction, params, attempts=15, timeout=0.06):
    """The bus is marginal when several servos share an id; insist until a frame validates."""
    for attempt in range(attempts):
        got = txrx(ser, servo_id, instruction, params, timeout)
        if got is not None:
            return got
        time.sleep(0.02)
    return None


def cmd_probe(ser, servo_id: int) -> int:
    got = retry(ser, servo_id, PING, [])
    if got is None:
        print(f"  no valid reply to a ping at id {servo_id} after 15 tries")
        return 1
    print(f"  ping      -> id {got[0]} err {got[1]} params {got[2]}")

    got = retry(ser, servo_id, READ, [ADDR_MODEL, 2])
    if got is None:
        print("  model number read FAILED (no valid reply)")
        return 1
    model = int.from_bytes(bytes(got[2][:2]), "big") if len(got[2]) >= 2 else None
    print(f"  model     -> {model}   ({'STS3215 (expected)' if model == MODEL_STS3215 else 'NOT an STS3215'})")

    for name, addr in (("id", ADDR_ID), ("baud index", ADDR_BAUD)):
        got = retry(ser, servo_id, READ, [addr, 1])
        print(f"  {name:<10}-> {got[2][0] if got and got[2] else 'read failed'}")
    return 0 if model == MODEL_STS3215 else 1


def cmd_set_id(ser, servo_id: int, new_id: int, baud_index: int | None) -> int:
    if new_id < 1 or new_id > 253:
        print("  new id must be 1..253")
        return 1
    if retry(ser, servo_id, PING, []) is None:
        print(f"  no servo answering at id {servo_id} — connect ONE servo and retry")
        return 1

    print("  unlocking EEPROM (torque off, lock 0)")
    txrx(ser, servo_id, WRITE, [ADDR_TORQUE, 0])
    txrx(ser, servo_id, WRITE, [ADDR_LOCK, 0])

    print(f"  writing id {servo_id} -> {new_id}")
    got = retry(ser, servo_id, WRITE, [ADDR_ID, new_id])
    print(f"    ack: {got}")

    if baud_index is not None:
        print(f"  writing baud index -> {baud_index}")
        got = retry(ser, servo_id, WRITE, [ADDR_BAUD, baud_index])
        print(f"    ack: {got}")

    txrx(ser, new_id, WRITE, [ADDR_LOCK, 1])

    print(f"  verifying: pinging the new id {new_id} ...")
    got = retry(ser, new_id, PING, [])
    if got is None:
        print("  !! no reply at the new id. Re-run `probe --expected-id 1` to see where it went.")
        return 1
    back = retry(ser, new_id, READ, [ADDR_ID, 1])
    print(f"  id now reads: {back[2][0] if back and back[2] else '?'}   (expected {new_id})")
    print("  OK — now disconnect this servo and connect the next one.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["probe", "set-id", "set-baud", "read", "write"])
    ap.add_argument("value", nargs="?", type=int, help="new id (set-id), baud index (set-baud), or register address (read/write)")
    ap.add_argument("--len", dest="length", type=int, default=1, help="bytes to read (read)")
    ap.add_argument("--value", dest="data", type=int, default=None, help="value to write (write)")
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--expected-id", type=int, default=1, help="id the servo answers on now (factory default 1)")
    ap.add_argument("--baud", type=int, default=1_000_000)
    ap.add_argument("--baud-index", type=int, default=None, help="optionally set the baud index too (0 = 1 Mbaud)")
    args = ap.parse_args()

    with serial.Serial(args.port, baudrate=args.baud, timeout=0.02, write_timeout=1.0) as ser:
        if args.action == "probe":
            print(f"probing id {args.expected_id} at {args.baud} baud")
            return cmd_probe(ser, args.expected_id)
        if args.action == "read":
            if args.value is None:
                ap.error("read needs the register address as the positional value")
            got = retry(ser, args.expected_id, READ, [args.value, args.length])
            print(f"  read addr {args.value} len {args.length} -> {got[2] if got else 'no valid reply'}")
            return 0 if got else 1
        if args.action == "write":
            if args.value is None or args.data is None:
                ap.error("write needs the register address (positional) and --value")
            print(f"  unlocking EEPROM, writing addr {args.value} = {args.data}")
            txrx(ser, args.expected_id, WRITE, [ADDR_TORQUE, 0])
            txrx(ser, args.expected_id, WRITE, [ADDR_LOCK, 0])
            got = retry(ser, args.expected_id, WRITE, [args.value, args.data])
            print(f"    ack: {got}")
            txrx(ser, args.expected_id, WRITE, [ADDR_LOCK, 1])
            back = retry(ser, args.expected_id, READ, [args.value, 1])
            print(f"    read back: {back[2][0] if back and back[2] else '?'}")
            return 0 if got else 1
        if args.value is None:
            ap.error("set-id/set-baud need a value")
        if args.action == "set-id":
            print(f"setting id {args.expected_id} -> {args.value}")
            return cmd_set_id(ser, args.expected_id, args.value, args.baud_index)
        if args.action == "set-baud":
            print(f"setting baud index {args.value} on id {args.expected_id}")
            got = retry(ser, args.expected_id, WRITE, [ADDR_BAUD, args.value])
            print(f"  ack: {got}")
            return 0 if got else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
