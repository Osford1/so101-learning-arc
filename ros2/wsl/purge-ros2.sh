#!/usr/bin/env bash
# Remove the ROS 2 stack from the Ubuntu-24.04 distro, KEEPING the distro itself.
#
# Why keep the distro: so_arm_ros2 (adityakamath) targets ROS 2 Jazzy on Ubuntu 24.04, which
# is exactly this distro. Re-creating a distro costs a rootfs download and the user account;
# what I actually want gone is the installed stack, the stale workspace and the env vars.

set -u
echo "[1/6] counting installed ros-jazzy packages"
dpkg -l 2>/dev/null | grep -c "^ii  ros-jazzy" | sed 's/^/   installed ros-jazzy packages: /'

echo "[2/6] purging ROS 2 (Jazzy), ros2_control/MoveIt/ros-gz come along as ros-jazzy-*"
sudo apt-get -y purge 'ros-jazzy-*' >/dev/null 2>&1
echo "   purge exit: $?"

echo "[3/6] purging tooling (colcon, rosdep, vcstool, ament)"
sudo apt-get -y purge 'python3-colcon-*' 'python3-rosdep*' 'python3-vcstool' 'python3-ament-*' 'python3-catkin-pkg*' >/dev/null 2>&1
echo "   purge exit: $?"

echo "[4/6] autoremove + apt source/keyring cleanup"
sudo apt-get -y autoremove --purge >/dev/null 2>&1
sudo rm -f /etc/apt/sources.list.d/ros2*.list /etc/apt/sources.list.d/ros2*.sources
sudo rm -f /usr/share/keyrings/ros-archive-keyring.gpg /usr/share/keyrings/ros2-latest-archive-keyring.gpg
sudo rm -rf /etc/ros
echo "   done"

echo "[5/6] removing workspaces and ROS user state"
rm -rf ~/so101_ws ~/ros2_ws ~/.ros ~/.colcon ~/.gazebo ~/.ignition ~/.cache/colcon
echo "   done"

echo "[6/6] cleaning ROS lines out of ~/.bashrc"
cp ~/.bashrc ~/.bashrc.bak-ros-cleanup 2>/dev/null
sed -i '/source \/opt\/ros/d; /ROS_AUTOMATIC_DISCOVERY_RANGE/d; /so101_ws/d; /ROS_DOMAIN_ID/d; /source .*install\/setup.bash/d' ~/.bashrc
echo "--- lines mentioning ROS/ros2 still in .bashrc ---"
grep -niE "ros|colcon|gazebo" ~/.bashrc || echo "   (none)"

echo
echo "===== VERIFY ====="
echo "apt ros-jazzy packages left: $(dpkg -l 2>/dev/null | grep -c '^ii  ros-jazzy')"
echo "/opt/ros:      $(ls /opt/ros 2>/dev/null || echo '(gone)')"
echo "~/so101_ws:    $(ls -d ~/so101_ws 2>/dev/null || echo '(gone)')"
echo "ros2 on PATH:  $(command -v ros2 || echo '(not found — clean)')"
echo "disk used:     $(df -h / | tail -1 | awk '{print $3" of "$2}')"
echo "DONE"
