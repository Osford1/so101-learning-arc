#!/usr/bin/env python3
"""
read_servo_ticks.py — read the follower's raw servo ticks (read-only, no motion).

Run it inside the LeRobot environment (conda `lerobot`, Ubuntu/WSL), with the arm
powered and attached. It answers the one question that decides whether ROS and
LeRobot agree about "zero":

    at the pose the arm is in right now, what tick does each servo report?

The ROS driver treats tick 2048 as joint angle 0, and `range_min`/`range_max`
from the calibration file as the tick limits. LeRobot reports DEGREES centred on
the MIDPOINT of those limits. If the midpoint is ~2048 the two stacks agree and
nothing else has to be configured.

Procedure for the bring-up test
-------------------------------
1. Power the follower, jog it BY HAND to the pose the URDF calls zero
   (the SO-ARM101 assembly's middle/zero pose).
2. Run this script. `ticks` should be close to 2048 for every joint.
3. `delta` (= ticks - 2048) is the offset ROS would need; feed it to
   lerobot_calib_to_ros_joints.py --ticks-at-zero ONLY if it is large.

    python3 read_servo_ticks.py --port /dev/ttyACM0 --id my_awesome_follower_arm
    python3 read_servo_ticks.py --json          # machine-readable

Safe: connect() with calibrate=False, torque stays off, nothing is written.
"""

from __future__ import annotations

import argparse
import json
import sys

TICK_CENTRE = 2048


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--id", dest="robot_id", default="my_awesome_follower_arm")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    args = ap.parse_args()

    from lerobot.robots.so_follower import SO101Follower, SO101FollowerConfig

    robot = SO101Follower(SO101FollowerConfig(port=args.port, id=args.robot_id))
    # calibrate=False: never jump into the interactive calibration prompt here.
    robot.connect(calibrate=False)
    try:
        ticks = robot.bus.sync_read("Present_Position", normalize=False)
        try:
            degrees = robot.bus.sync_read("Present_Position")
        except Exception:
            degrees = {}
        calib = robot.bus.calibration

        rows = []
        for name, motor in robot.bus.motors.items():
            c = calib.get(name)
            rmin = int(c.range_min) if c else None
            rmax = int(c.range_max) if c else None
            mid = ((rmin + rmax) / 2) if (rmin is not None and rmax is not None) else None
            rows.append(
                {
                    "joint": name,
                    "id": motor.id,
                    "ticks": int(ticks[name]),
                    "degrees": round(float(degrees[name]), 2) if name in degrees else None,
                    "range_min": rmin,
                    "range_max": rmax,
                    "range_mid": mid,
                    "lerobot_homing_offset": int(c.homing_offset) if c else None,
                    "drive_mode": int(c.drive_mode) if c else None,
                    "ros_homing_offset": int(ticks[name]) - TICK_CENTRE,
                }
            )

        if args.json:
            print(json.dumps({"port": args.port, "id": args.robot_id, "joints": rows}, indent=2))
        else:
            print(f"port={args.port}  id={args.robot_id}")
            print(f"{'joint':<15}{'id':>3}{'ticks':>7}{'deg':>9}{'range_mid':>11}{'delta(ros)':>12}{'drive_mode':>11}")
            for r in rows:
                print(
                    f"{r['joint']:<15}{r['id']:>3}{r['ticks']:>7}"
                    f"{(r['degrees'] if r['degrees'] is not None else float('nan')):>9.2f}"
                    f"{(r['range_mid'] if r['range_mid'] is not None else float('nan')):>11.1f}"
                    f"{r['ros_homing_offset']:>12d}{r['drive_mode']:>11}"
                )
            print(
                "\n`delta(ros)` = ticks - 2048 = the homing_offset ROS would need IF you decide\n"
                "ROS zero is not where it is now. Leave it alone unless a joint is way off."
            )
    finally:
        robot.disconnect()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
