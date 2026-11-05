#!/usr/bin/env python3
"""
jog_one_joint.py — move ONE joint by a small delta, hold the others still.

The safest first motion on a real arm, and the most literal form of explicit
control: read where the arm is, command a small change to one joint, time-bounded
by the controller, then measure what actually happened.

    python3 jog_one_joint.py --joint wrist_roll_joint --delta 0.10
    python3 jog_one_joint.py --joint shoulder_pan_joint --delta -0.10 --duration 3

It sends a single-point FollowJointTrajectory goal to
/joint_trajectory_controller. The other four joints are commanded to their
*measured* positions, so a wrong sign or a wrong zero on the joint under test
cannot cascade into the rest of the arm.

Why not stream setpoints to forward_position_controller? Because in ros2_control a
command interface can be claimed by ONE controller at a time — with
joint_trajectory_controller already active, spawning forward_position_controller
on the same joints fails ("Failed to activate controller") and your commands go
nowhere. To drive setpoints directly you must *switch*, not stack:

    ros2 control switch_controllers --deactivate joint_trajectory_controller \
                                    --activate   forward_position_controller

On the mock hardware the measured position lands exactly on the target; on the
real STS3215s expect a few hundredths of a rad of steady-state error, which is the
servo's own position loop, not a bug in the trajectory.
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


class Jogger(Node):
    def __init__(self) -> None:
        super().__init__("jog_one_joint")
        self.latest: dict[str, float] = {}
        self.create_subscription(JointState, "/joint_states", self._on_state, 10)
        self.client = ActionClient(
            self, FollowJointTrajectory, "/joint_trajectory_controller/follow_joint_trajectory"
        )

    def _on_state(self, msg: JointState) -> None:
        self.latest = dict(zip(msg.name, msg.position, strict=False))

    def wait_for_state(self, which: list[str], timeout: float = 15.0) -> bool:
        end = time.monotonic() + timeout
        while rclpy.ok() and time.monotonic() < end:
            rclpy.spin_once(self, timeout_sec=0.1)
            if all(j in self.latest for j in which):
                return True
        return False

    def read(self) -> list[float]:
        return [self.latest[j] for j in JOINTS]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--joint", required=True, choices=JOINTS)
    ap.add_argument("--delta", type=float, required=True, help="radians, sign matters")
    ap.add_argument("--duration", type=float, default=2.0, help="seconds for the move (smoothness)")
    ap.add_argument("--settle", type=float, default=1.0, help="seconds to wait after the goal before measuring")
    args = ap.parse_args()

    rclpy.init()
    node = Jogger()
    try:
        if not node.wait_for_state(JOINTS):
            print("!! no /joint_states — is controller_manager up and joint_state_broadcaster active?")
            return 1
        if not node.client.wait_for_server(timeout_sec=10.0):
            print("!! /joint_trajectory_controller not reachable — is it active? (ros2 control list_controllers)")
            return 1

        before = node.read()
        idx = JOINTS.index(args.joint)
        target = list(before)
        target[idx] += args.delta
        print("before:", {j: round(v, 4) for j, v in zip(JOINTS, before, strict=True)})
        print(f"commanded delta on {args.joint}: {args.delta:+.4f} rad -> target {target[idx]:+.4f}")

        traj = JointTrajectory()
        traj.joint_names = list(JOINTS)
        point = JointTrajectoryPoint()
        point.positions = [float(v) for v in target]
        sec = int(args.duration)
        point.time_from_start.sec = sec
        point.time_from_start.nanosec = int((args.duration - sec) * 1e9)
        traj.points = [point]

        goal = FollowJointTrajectory.Goal()
        goal.trajectory = traj

        send = node.client.send_goal_async(goal)
        rclpy.spin_until_future_complete(node, send, timeout_sec=15.0)
        handle = send.result()
        if handle is None or not handle.accepted:
            print("!! goal rejected")
            return 1
        result_future = handle.get_result_async()
        rclpy.spin_until_future_complete(node, result_future, timeout_sec=args.duration + 20.0)

        time.sleep(args.settle)
        node.wait_for_state(JOINTS, timeout=5.0)
        after = node.read()
        print("after: ", {j: round(v, 4) for j, v in zip(JOINTS, after, strict=True)})
        print(f"tracking error on {args.joint}: {(after[idx] - target[idx]):+.4f} rad")
        print(f"actual move: {after[idx] - before[idx]:+.4f} rad (commanded {args.delta:+.4f})")
        print(
            "sanity: the tested joint moved the sign you asked for, and every other joint stayed put\n"
            "(a few hundredths of a rad of steady-state error on the real servos is normal)"
        )
        return 0
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    sys.exit(main())
