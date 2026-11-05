#!/usr/bin/env python3
"""
move_arm.py — move the SO-101 follower to a chosen joint configuration.

This is the "program the arm to move to a specific spot" tool for the JOINT-space rung of
the arc: you name the joint angles, the trajectory controller interpolates to them over a
chosen duration, and the servo's own position loop does the tracking.

    python3 move_arm.py --show                              # read the current pose
    python3 move_arm.py --pose 0.0,-0.5,0.6,-0.4,0.0         # go to those angles (radians)
    python3 move_arm.py --pose 0,0,0,0,0 --duration 5         # slower / gentler
    python3 move_arm.py --relative 0.0,0.1,0.0,0.0,0.0        # nudge from wherever it is

Joint order is fixed and matches the controller config:
    shoulder_pan, shoulder_lift, elbow_flex, wrist_flex, wrist_roll      (gripper untouched)

Safety: a move whose largest joint delta exceeds --max-delta (default 0.6 rad ≈ 34°) is
refused unless you pass --force. On a real arm that is the difference between a deliberate
move and a slam, and it also catches the classic mistake of feeding degrees instead of
radians. Nothing here writes to servo EEPROM — it only sends a trajectory.

A CARTESIAN "spot" (an x/y/z position for the gripper) is a different job: it needs inverse
kinematics, i.e. MoveIt 2 or a small IK node — see the arc's Phase 3. This tool moves joints.
"""

from __future__ import annotations

import argparse
import sys
import time

import rclpy
from control_msgs.action import FollowJointTrajectory
from rclpy.action import ActionClient
from rclpy.node import Node
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint

JOINTS = [
    "shoulder_pan_joint",
    "shoulder_lift_joint",
    "elbow_flex_joint",
    "wrist_flex_joint",
    "wrist_roll_joint",
]


class ArmMover(Node):
    def __init__(self) -> None:
        super().__init__("move_arm")
        self.latest: dict[str, float] = {}
        self.create_subscription(JointState, "/joint_states", self._on_state, 10)
        self.client = ActionClient(
            self, FollowJointTrajectory, "/joint_trajectory_controller/follow_joint_trajectory"
        )

    def _on_state(self, msg: JointState) -> None:
        for name, pos in zip(msg.name, msg.position, strict=False):
            self.latest[name] = pos

    def wait_for_state(self, timeout: float = 15.0) -> bool:
        end = time.monotonic() + timeout
        while rclpy.ok() and time.monotonic() < end:
            rclpy.spin_once(self, timeout_sec=0.1)
            if all(j in self.latest for j in JOINTS):
                return True
        return False

    def pose(self) -> list[float]:
        return [self.latest[j] for j in JOINTS]


def fmt(values: list[float]) -> str:
    return "  ".join(f"{n.split('_joint')[0]}={v:+.4f}" for n, v in zip(JOINTS, values, strict=True))


def send_goal(node: ArmMover, target: list[float], duration: float) -> int:
    if not node.client.wait_for_server(timeout_sec=10.0):
        print("!! trajectory controller not reachable — is it active? (ros2 control list_controllers)")
        return 1
    traj = JointTrajectory()
    traj.joint_names = list(JOINTS)
    point = JointTrajectoryPoint()
    point.positions = [float(v) for v in target]
    point.time_from_start.sec = int(duration)
    point.time_from_start.nanosec = int((duration - int(duration)) * 1e9)
    traj.points = [point]
    goal = FollowJointTrajectory.Goal()
    goal.trajectory = traj

    send = node.client.send_goal_async(goal)
    rclpy.spin_until_future_complete(node, send, timeout_sec=15.0)
    handle = send.result()
    if handle is None or not handle.accepted:
        print("!! goal rejected by the controller")
        return 1
    result_future = handle.get_result_async()
    rclpy.spin_until_future_complete(node, result_future, timeout_sec=duration + 25.0)
    result = result_future.result()
    if result is not None and getattr(result, "result", None) is not None:
        err = getattr(result.result, "error_code", -1)
        print(f"   controller result: error_code={err} "
              f"('{'Goal successfully reached!' if err == 0 else 'see error_code'})")
    return 0


def parse_pose(text: str) -> list[float]:
    parts = [p.strip() for p in text.replace(";", ",").split(",") if p.strip()]
    if len(parts) != len(JOINTS):
        sys.exit(f"--pose needs {len(JOINTS)} comma-separated values in radians "
                 f"({', '.join(j.split('_joint')[0] for j in JOINTS)}); got {len(parts)}")
    try:
        return [float(p) for p in parts]
    except ValueError as exc:
        sys.exit(f"--pose values must be numbers in radians: {exc}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--show", action="store_true", help="print the current joint pose and exit")
    ap.add_argument("--pose", help="target joint angles, radians, comma-separated (5 values)")
    ap.add_argument("--relative", help="delta to apply to the current pose, radians (5 values)")
    ap.add_argument("--duration", type=float, default=3.0, help="seconds for the move (default 3)")
    ap.add_argument("--settle", type=float, default=1.0, help="seconds to wait before reporting")
    ap.add_argument("--max-delta", type=float, default=0.6, help="refuse a move larger than this per joint (rad)")
    ap.add_argument("--force", action="store_true", help="allow a large move anyway")
    args = ap.parse_args()

    if not args.show and not args.pose and not args.relative:
        ap.print_help()
        return 0

    rclpy.init()
    node = ArmMover()
    try:
        if not node.wait_for_state():
            print("!! no /joint_states — is the bring-up running and joint_state_broadcaster active?")
            return 1
        current = node.pose()

        if args.show:
            print("current pose (radians):")
            print("   " + fmt(current))
            print("   " + "  ".join(f"{n}={v:+.4f}" for n, v in zip(JOINTS, current, strict=True)))
            return 0

        target = parse_pose(args.pose) if args.pose else [
            c + d for c, d in zip(current, parse_pose(args.relative), strict=True)
        ]

        deltas = [t - c for t, c in zip(target, current, strict=True)]
        biggest = max(abs(d) for d in deltas)
        print("current: " + fmt(current))
        print("target:  " + fmt(target))
        print("delta:   " + fmt(deltas) + f"   (largest {biggest:.3f} rad)")

        if biggest > args.max_delta and not args.force:
            print(f"\n!! REFUSED: the largest joint delta is {biggest:.3f} rad, above the "
                  f"--max-delta limit of {args.max_delta:.2f} rad.")
            print("   That guard exists so a typo (degrees instead of radians, or a wrong sign) cannot")
            print("   throw the arm. Move in smaller steps, or pass --force if this is deliberate.")
            return 2

        print(f"\nmoving over {args.duration:.1f} s ...")
        rc = send_goal(node, target, args.duration)
        time.sleep(args.settle)
        rclpy.spin_once(node, timeout_sec=0.2)
        after = node.pose()
        print("after:   " + fmt(after))
        print("residual:" + fmt([a - t for a, t in zip(after, target, strict=True)]))
        print("(a few hundredths of a rad of residual on the real servos is their own position loop)")
        return rc
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    sys.exit(main())
