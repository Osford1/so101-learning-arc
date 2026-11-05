#!/usr/bin/env bash
# Why won't so_arm_controller activate? Find the interfaces the mock hardware actually exports.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST ROS2CLI_NO_DAEMON=1

echo "########## 1. hardware interfaces actually offered ##########"
timeout 30 ros2 control list_hardware_interfaces --no-daemon > /tmp/hw.txt 2>&1 < /dev/null
cat /tmp/hw.txt
echo
echo "  --- command interfaces only ---"
grep -E "command" /tmp/hw.txt | head -20

echo
echo "########## 2. what the launch log said at startup ##########"
head -45 "$HOME/phase0-mock.log"

echo
echo "########## 3. what does sts_hardware_interface export in mock mode? ##########"
cd "$HOME/ros2_ws/src/sts_hardware_interface" || exit 1
grep -rn "export_command_interfaces\|export_state_interfaces" --include=*.cpp --include=*.hpp . | head -10
echo "  --- mock-related code paths ---"
grep -rn "mock" --include=*.cpp --include=*.hpp --include=*.xacro --include=*.urdf -il . | head -10
