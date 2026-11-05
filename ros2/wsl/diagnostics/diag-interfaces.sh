#!/usr/bin/env bash
# Decisive: what interfaces exist, and what the URDF asks for.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. list_hardware_interfaces (no --no-daemon: unsupported there) ##########"
timeout 30 ros2 control list_hardware_interfaces > /tmp/hw.txt 2>&1 < /dev/null
echo "  exit=$?"
cat /tmp/hw.txt
echo
echo "  --- only lines mentioning command ---"
grep -i command /tmp/hw.txt | cut -c1-160

echo
echo "########## 2. is the stack still alive? ##########"
pgrep -af "so_arm_bringup|ros2_control_node" | cut -c1-110 | sed 's/^/  /' || echo "  (nothing)"

echo
echo "########## 3. what does the SO-101 URDF declare as command interfaces? ##########"
grep -rn "command_interface" "$HOME"/ros2_ws/src/so_arm_ros2/so_arm_description/urdf/so101/*.xacro \
  | cut -c1-170 | sed 's/^/  /'

echo
echo "########## 4. sts_hardware_interface: how are command interfaces exported? ##########"
grep -n "export_command_interfaces" -A 40 "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp \
  | grep -nE "position|velocity|pwm|effort|mock|if |else" | head -25 | sed 's/^/  /'

echo
echo "########## 5. mock specifics in the hardware interface ##########"
grep -niE "mock" "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp | head -20 | cut -c1-170 | sed 's/^/  /'
