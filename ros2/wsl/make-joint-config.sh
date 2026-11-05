#!/usr/bin/env bash
# make-joint-config.sh — LeRobot calibration JSON → the driver's joint_config_file.
#
#   bash make-joint-config.sh /mnt/c/path/to/so101-learning-arc/ros2/calib/my_awesome_follower_arm.json
#   bash make-joint-config.sh                      # auto-finds the newest file in the LeRobot cache
#
# The file it writes is the SAME file the installed package reads (colcon --symlink-install
# symlinks install/.../config/*.yaml back to src/.../config/*.yaml), so no rebuild is needed.
#
# It deliberately does NOT set homing_offset: that parameter is written to the servo EEPROM and
# LeRobot already put its own value there. Read the notes it prints at the end.

set -euo pipefail

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools" && pwd)"
OUT="$HOME/so101_ws/src/so101_local/config/so101_follower_joints.yaml"
CALIB="${1:-}"

ARGS=(--out "$OUT")
[ -n "$CALIB" ] && ARGS=(--calib "$CALIB" "${ARGS[@]}")

echo "== converting -> $OUT =="
python3 "${TOOLS}/lerobot_calib_to_ros_joints.py" "${ARGS[@]}"

echo
echo "== the installed package now sees: =="
grep -E "^  [a-z_]+:|id:|range_min|range_max|homing_offset" "$OUT" | head -30
echo
echo "Next: cd into the ROS distro and run"
echo "  bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/run-real-follower.sh /dev/ttyACM0"
