#!/usr/bin/env python3
"""
joint_state_snapshot.py — turn a /joint_states message dump into something readable.

    ros2 topic echo /joint_states --once | python3 joint_state_snapshot.py
    python3 joint_state_snapshot.py --diff before.txt after.txt

The first form prints one `joint=value` pair per joint (radians, signed), in the order the
message publishes them — which is NOT the order you commanded (ROS sorts alphabetically), so
reading raw YAML is a good way to fool yourself about a sign flip.

The --diff form is the useful one after a motion: it reports what actually moved.
"""

from __future__ import annotations

import argparse
import sys


def parse(text: str) -> dict[str, float]:
    names: list[str] = []
    positions: list[float] = []
    section = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("name:"):
            section = "name"
        elif line.startswith("position:"):
            section = "position"
        elif line.startswith(("velocity:", "effort:", "header:")):
            section = None
        elif line.startswith("-") and section == "name":
            names.append(line[1:].strip())
        elif line.startswith("-") and section == "position":
            try:
                positions.append(float(line[1:].strip()))
            except ValueError:
                pass
    return dict(zip(names, positions, strict=False))


def show(values: dict[str, float]) -> None:
    print("   " + "  ".join(f"{n}={v:+.4f}" for n, v in values.items()))


def diff(before: dict[str, float], after: dict[str, float]) -> int:
    moved = {k: after[k] - v for k, v in before.items() if k in after and abs(after[k] - v) > 1e-4}
    print("   " + "  ".join(f"{n}={v:+.4f}" for n, v in before.items()))
    print("   " + "  ".join(f"{n}={v:+.4f}" for n, v in after.items()))
    if not moved:
        print("   delta: nothing moved")
        return 1
    print("   delta: " + "  ".join(f"{n}={d:+.4f}" for n, d in moved.items()))
    print("   " + "  ".join(f"{n}={after[n]:+.4f}" for n in after) + "   <- commanded end state should match this")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="with --diff: before-file after-file")
    ap.add_argument("--diff", action="store_true", help="compare two saved snapshots")
    args = ap.parse_args()

    if args.diff:
        if len(args.files) != 2:
            return "usage: joint_state_snapshot.py --diff before.txt after.txt"  # type: ignore[return-value]
        with open(args.files[0], encoding="utf-8") as fh:
            before = parse(fh.read())
        with open(args.files[1], encoding="utf-8") as fh:
            after = parse(fh.read())
        return diff(before, after)

    values = parse(sys.stdin.read())
    if not values:
        print("   (no joint positions parsed — is /joint_states publishing?)")
        return 1
    show(values)
    return 0


if __name__ == "__main__":
    sys.exit(main())
