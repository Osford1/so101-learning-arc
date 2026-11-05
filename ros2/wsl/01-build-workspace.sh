#!/usr/bin/env bash
# 01-build-workspace.sh — clone + build the SO-101 ROS 2 explicit-control workspace
#
#   bash 01-build-workspace.sh
#
# Creates ~/so101_ws with:
#   src/ros2_so_arm            upstream: SO-ARM100/101 description + ros2_control launch + MoveIt config
#   src/feetech_ros2_driver    upstream: ros2_control hardware interface for the STS3215 servos
#   src/so101_local            ours: controller config + joint/EERPROM config + real-hardware xacro
#
# Safe to re-run (git pull + rebuild).

set -euo pipefail

ROS_DISTRO=jazzy
WS="$HOME/so101_ws"
LOCAL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ws_src/so101_local"   # ros2/ws_src/so101_local

# WSL2 'mirrored' networking breaks DDS multicast discovery: without this,
# nodes/CLI never see each other (controller_manager never gets robot_description).
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
set +u; source "/opt/ros/${ROS_DISTRO}/setup.bash"; set -u

echo "== 1. workspace skeleton =="
mkdir -p "$WS/src"
cd "$WS/src"

echo "== 2. upstream packages =="
[ -d ros2_so_arm ]         && git -C ros2_so_arm pull --ff-only         || git clone https://github.com/ros-physical-ai/ros2_so_arm.git
[ -d feetech_ros2_driver ] && git -C feetech_ros2_driver pull --ff-only || git clone https://github.com/ros-physical-ai/feetech_ros2_driver.git

echo "== 3. my local overlay package =="
rm -rf so101_local
cp -r "$LOCAL_SRC" so101_local

echo "== 4. rosdep =="
cd "$WS"
sudo rosdep install --from-paths src --ignore-src -r -y || true
# the driver's C++ deps, in case rosdep can't resolve every key:
sudo apt-get install -y -qq libserial-dev libexpected-dev libspdlog-dev libfmt-dev librange-v3-dev libyaml-cpp-dev

echo "== 5. build =="
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

echo
echo "DONE. In every new shell:"
echo "  source /opt/ros/${ROS_DISTRO}/setup.bash && source $WS/install/setup.bash"
echo "Then:  bash wsl/run-mock.sh     # no hardware, proves the control loop"
