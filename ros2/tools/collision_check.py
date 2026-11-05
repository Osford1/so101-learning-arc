#!/usr/bin/env python3
"""Collision detector: is more than one device answering on id 1?

If two servos share id 1, a single ping pulls two replies, so some responses contain two
FF FF headers (or 12 bytes instead of 6). This is the software test for "the chain is still
attached / something else is on the bus" without touching the hardware.

Usage: script.py /dev/ttyACM0 [tries]
"""
import sys, time, serial

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
TRIES = int(sys.argv[2]) if len(sys.argv) > 2 else 25

def cks(b): return (~sum(b)) & 0xFF
def ping_frame(sid): 
    body = [sid, 2, 0x01]
    return bytes([0xFF, 0xFF, *body, cks(body)])

multi = 0
lengths = {}
samples = []
with serial.Serial(PORT, baudrate=1_000_000, timeout=0.02, write_timeout=1.0) as ser:
    time.sleep(0.2)
    for _ in range(TRIES):
        ser.reset_input_buffer()
        ser.write(ping_frame(1)); ser.flush()
        t0 = time.monotonic(); buf = bytearray()
        while time.monotonic() - t0 < 0.08:
            c = ser.read(64)
            if c: buf.extend(c)
        n_headers = sum(1 for i in range(len(buf) - 1) if buf[i] == 0xFF and buf[i + 1] == 0xFF)
        lengths[len(buf)] = lengths.get(len(buf), 0) + 1
        if n_headers > 1:
            multi += 1
            samples.append(bytes(buf).hex(" "))
    if samples:
        print("responses containing MORE THAN ONE frame header:")
        for s in samples[:5]:
            print("   ", s)

print(f"tries {TRIES}, response-byte-length histogram: {dict(sorted(lengths.items()))}")
print(f"responses with >1 FF FF header (= two devices answering): {multi}/{TRIES}")
if multi == 0:
    print("VERDICT: only ONE device is answering on id 1 — no collision.")
else:
    print("VERDICT: COLLISION — more than one servo is on the bus at id 1.")
