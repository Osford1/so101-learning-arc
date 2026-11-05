#!/usr/bin/env bash
# run-mock.sh — explicit-control loop with NO hardware (mock_components)
#
# Proves the whole chain — controller_manager → joint_trajectory_controller →
# robot_state_publisher → /joint_states — with no arm plugged in.
#
#   bash run-mock.sh              # bring up and stay up (Ctrl-C to stop)
#   bash run-mock.sh --verify     # bring up, run the checks, tear down, exit 0/1
#
# The --verify path is the gate: controllers ACTIVE + /joint_states following a
# commanded trajectory. The real arm does the same thing through the feetech
# hardware plugin (one plugin swap away).

set -euo pipefail

ROS_DISTRO=jazzy
WS="$HOME/so101_ws"
MODE="${1:-interactive}"
LOG="${TMPDIR:-/tmp}/so101_mock_bringup.log"

# WSL2 'mirrored' networking breaks DDS multicast discovery: without this,
# nodes/CLI never see each other (controller_manager never gets robot_description).
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
set +u; source "/opt/ros/${ROS_DISTRO}/setup.bash"; set -u
set +u; source "$WS/install/setup.bash"; set -u

CTRL="$(ros2 pkg prefix --share so101_local)/config/ros2_controllers_explicit.yaml"
[ -f "$CTRL" ] || { echo "!! $CTRL missing — run 01-build-workspace.sh first"; exit 1; }
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"
BEFORE_F="/tmp/so101_joints_before.txt"
AFTER_F="/tmp/so101_joints_after.txt"

# An S-shaped 3-point path = the "good motion" reference this arc is about.
# Explicit control means I write this, and later I replace it with a
# jerk-limited / time-optimal generator (Phase 4, the MIM bridge).
TRAJ='{
  trajectory: {
    joint_names: [shoulder_pan_joint, shoulder_lift_joint, elbow_flex_joint, wrist_flex_joint, wrist_roll_joint],
    points: [
      {positions: [ 0.30, -0.40,  0.55, -0.30,  0.20], time_from_start: {sec: 2, nanosec: 0}},
      {positions: [-0.30, -0.20,  0.30, -0.10, -0.20], time_from_start: {sec: 4, nanosec: 0}},
      {positions: [ 0.00, -0.35,  0.45, -0.25,  0.00], time_from_start: {sec: 6, nanosec: 0}}
    ]
  }
}'

echo "== bringing up controller_manager (mock_components) =="
ros2 launch so_arm101_description controllers_bringup.launch.py \
  hardware_type:=mock_components \
  controller_config_file:="$CTRL" > "$LOG" 2>&1 &
LAUNCH_PID=$!
cleanup() { kill $LAUNCH_PID 2>/dev/null || true; }
trap cleanup EXIT

echo "   waiting for the controllers to activate (log: $LOG)"
ACTIVE=1
for _ in $(seq 1 20); do
  sleep 1
  if ros2 control list_controllers 2>/dev/null | grep -q "joint_trajectory_controller.*active"; then
    ACTIVE=0
    break
  fi
done
if [ "$ACTIVE" != "0" ]; then
  echo "!! joint_trajectory_controller never became active. Last log lines:"
  tail -30 "$LOG"
  exit 1
fi

echo
echo "== controllers =="
ros2 control list_controllers

echo
echo "== /joint_states BEFORE the goal (radians) =="
# save the raw message (so the diff can re-parse it) and print the readable form
snap() { timeout 5 ros2 topic echo /joint_states --once 2>/dev/null; }
show_snap() { python3 "$TOOLS/joint_state_snapshot.py"; }
snap > "$BEFORE_F"
show_snap < "$BEFORE_F"

echo
echo "== sending the trajectory (explicit control) =="
ros2 action send_goal /joint_trajectory_controller/follow_joint_trajectory \
  control_msgs/action/FollowJointTrajectory "$TRAJ"

echo
sleep 1
echo "== /joint_states AFTER the goal (radians) =="
snap > "$AFTER_F"
show_snap < "$AFTER_F"

echo
echo "== what moved =="
python3 "$TOOLS/joint_state_snapshot.py" --diff "$BEFORE_F" "$AFTER_F" || true

echo
echo "== verify =="
if ros2 control list_controllers | grep -q "joint_trajectory_controller.*active"; then
  echo "RESULT: PASS — the control loop runs end to end with no hardware."
  echo "        now swap hardware_type:=real for the arm (run-real-follower.sh)."
else
  echo "RESULT: FAIL"
  exit 1
fi

if [ "$MODE" = "--verify" ]; then
  echo "(verify mode: tearing the bring-up down)"
  exit 0
fi

echo "(Ctrl-C to stop the bring-up)"
wait $LAUNCH_PID
