#!/usr/bin/env bash
# run-real-follower.sh — EXPLICIT CONTROL of the real SO-101 follower.
#
#   bash run-real-follower.sh                       # /dev/ttyACM0
#   bash run-real-follower.sh /dev/ttyACM1
#
# Preconditions (checked below):
#   1. arm powered: follower = 12 V PSU *and* USB-C to the PC
#   2. Windows side: usbipd attached the CH34x adapter to this WSL distro
#      (ros2/windows/attach-arm.ps1)
#   3. joint_config_file generated from the LeRobot calibration
#      (ros2/tools/lerobot_calib_to_ros_joints.py)
#
# WARNING - FIRST RUN = SUPERVISED. The controller drives the servos as soon as a
#    trajectory arrives. Hand on the 12 V PSU switch, arm clear of everything.
#    Then use test-one-joint.sh, not a full-arm trajectory.

set -euo pipefail

ROS_DISTRO=jazzy
WS="$HOME/so101_ws"
PORT="${1:-/dev/ttyACM0}"

# WSL2 'mirrored' networking breaks DDS multicast discovery: without this,
# nodes/CLI never see each other (controller_manager never gets robot_description).
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
set +u; source "/opt/ros/${ROS_DISTRO}/setup.bash"; set -u
set +u; source "$WS/install/setup.bash"; set -u

SHARE="$(ros2 pkg prefix --share so101_local)"
XACRO="${SHARE}/urdf/so_arm101_local.ros2_control.xacro"
JOINTS="${SHARE}/config/so101_follower_joints.yaml"
CTRL="${SHARE}/config/ros2_controllers_explicit.yaml"

echo "== 0. preflight =="
ls -l /dev/ttyACM* 2>/dev/null || { echo "!! $PORT not present — did usbipd attach the arm?"; exit 1; }
grep -q REPLACE_ME "$JOINTS" && {
  echo "!! $JOINTS still has REPLACE_ME — generate it from the LeRobot calibration first:"
  echo "   bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/make-joint-config.sh <path-to-calibration.json>"
  exit 1
}
sudo chmod 666 "$PORT"
echo "   $PORT ok"

echo
echo "WARNING: about to hand the servos to ros2_control."
echo "    - arm clear of the desk edge / cables"
echo "    - hand on the 12 V PSU switch"
read -r -p "    type YES to continue: " ok
[ "$ok" = "YES" ] || { echo "aborted"; exit 1; }

echo "== 1. bring-up: real hardware =="
ros2 launch so_arm101_description controllers_bringup.launch.py \
  hardware_type:=real \
  usb_port:="$PORT" \
  ros2_control_xacro_file:="$XACRO" \
  controller_config_file:="$CTRL"
