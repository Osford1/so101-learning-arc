#!/usr/bin/env bash
# Phase 0, steps 1-6 for the SO-101 / so_arm_ros2 stack. Runs INSIDE WSL Ubuntu-24.04.
# Full log also lands at ~/phase0-install.log inside the distro.

LOG="$HOME/phase0-install.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== PHASE 0 INSTALL START $(date -Is) ==="
echo

echo "### [2] bashrc hygiene (DDS discovery + ROS env)"
grep -q 'source /opt/ros/jazzy/setup.bash' "$HOME/.bashrc" || echo 'source /opt/ros/jazzy/setup.bash' >> "$HOME/.bashrc"
grep -q 'ROS_AUTOMATIC_DISCOVERY_RANGE'     "$HOME/.bashrc" || echo 'export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST' >> "$HOME/.bashrc"
echo "  ok"

echo
echo "### [1a] ROS 2 signing key"
sudo curl -x http://127.0.0.1:PORT -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "  key file first line: $(head -1 /usr/share/keyrings/ros-archive-keyring.gpg)"
echo "  key bytes: $(stat -c%s /usr/share/keyrings/ros-archive-keyring.gpg)"

echo "### [1b] ROS 2 apt repo (Tsinghua mirror)"
. /etc/os-release
echo "  distro codename: $VERSION_CODENAME   arch: $(dpkg --print-architecture)"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu $VERSION_CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
cat /etc/apt/sources.list.d/ros2.list

echo "### [1c] apt update"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
echo "  update exit: $?"

echo "### [1d] install ros-jazzy-desktop  (largest step, ~1.5 GB)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ros-jazzy-desktop
echo "  ros-jazzy-desktop exit: $?"

echo
echo "### [3] dependency set (upstream CI's Jazzy list)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3-pip python3-yaml python3-numpy python3-opencv git libfcl-dev \
  ros-jazzy-ament-index-python ros-jazzy-control-msgs ros-jazzy-controller-manager \
  ros-jazzy-controller-manager-msgs ros-jazzy-cv-bridge ros-jazzy-diagnostic-msgs \
  ros-jazzy-effort-controllers ros-jazzy-hardware-interface ros-jazzy-joint-state-broadcaster \
  ros-jazzy-joint-trajectory-controller ros-jazzy-joy ros-jazzy-joy-teleop \
  ros-jazzy-launch-testing ros-jazzy-launch-testing-ros ros-jazzy-parallel-gripper-controller \
  ros-jazzy-pinocchio ros-jazzy-pluginlib ros-jazzy-rclcpp-lifecycle \
  ros-jazzy-robot-state-publisher ros-jazzy-ros2-control ros-jazzy-ros2-controllers \
  ros-jazzy-rosidl-default-generators ros-jazzy-std-srvs ros-jazzy-tf2-ros ros-jazzy-xacro \
  ros-jazzy-rosbag2-storage-mcap ros-jazzy-mujoco-ros2-control
echo "  deps exit: $?"

echo
echo "### [4] python deps, CI invocation (--user --ignore-installed: numpy ABI matters)"
python3 -m pip install --break-system-packages --user --ignore-installed \
  -i https://pypi.tuna.tsinghua.edu.cn/simple python-fcl numpy-stl
echo "  pip exit: $?"
python3 -c "import fcl, stl; print('  import check OK: fcl + stl')" || echo "  !! import check FAILED"

echo
echo "### [5] workspace + repos (via the local proxy)"
mkdir -p "$HOME/ros2_ws/src" && cd "$HOME/ros2_ws/src" || exit 1
G="git -c http.proxy=http://127.0.0.1:PORT -c https.proxy=http://127.0.0.1:PORT"
[ -d so_arm_ros2 ]           || $G clone https://github.com/adityakamath/so_arm_ros2.git
[ -d sts_hardware_interface ] || $G clone --recursive https://github.com/adityakamath/sts_hardware_interface.git
echo "  src/ contains:"; ls -d "$HOME"/ros2_ws/src/*/
if [ -f "$HOME/ros2_ws/src/sts_hardware_interface/external/SCServo_Linux/SCServo.h" ] || [ -d "$HOME/ros2_ws/src/sts_hardware_interface/external/SCServo_Linux" ]; then
  echo "  submodule OK: $(ls "$HOME"/ros2_ws/src/sts_hardware_interface/external/SCServo_Linux | tr '\n' ' ')"
else
  echo "  !! SCServo_Linux submodule MISSING"
fi

echo
echo "### [6] colcon build (plain: sts_hardware_interface must be built too)"
cd "$HOME/ros2_ws" || exit 1
source /opt/ros/jazzy/setup.bash
colcon build
echo "  build exit: $?"
source install/setup.bash 2>/dev/null
echo "  packages built:"
ros2 pkg list 2>/dev/null | grep -E "so_arm|sts_hardware" | sed 's/^/    /'

echo
echo "=== PHASE 0 INSTALL DONE $(date -Is) ==="
