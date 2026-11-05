#!/usr/bin/env bash
# test-one-joint.sh — the FIRST thing to run once the real follower is up.
#
# One joint, 0.10 rad, the other four held at their measured positions. Nothing
# else moves, so an inverted sign / wrong zero / wrong limit shows up as a small
# wrong motion instead of a full-arm throw.
#
#   bash test-one-joint.sh                       # wrist_roll_joint (safest joint)
#   bash test-one-joint.sh shoulder_pan_joint 0.05
#
# Run this while run-real-follower.sh is up in another terminal.

set -euo pipefail

ROS_DISTRO=jazzy
JOINT="${1:-wrist_roll_joint}"
DELTA="${2:-0.10}"
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"

export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
set +u; source "/opt/ros/${ROS_DISTRO}/setup.bash"; set -u
if [ -f "$HOME/so101_ws/install/setup.bash" ]; then
  set +u; source "$HOME/so101_ws/install/setup.bash"; set -u
fi

echo "== controllers =="
ros2 control list_controllers

echo
echo "== jog: $JOINT by ${DELTA} rad =="
python3 "$TOOLS/jog_one_joint.py" --joint "$JOINT" --delta "$DELTA" --duration 2 --settle 1
