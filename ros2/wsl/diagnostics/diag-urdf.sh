#!/usr/bin/env bash
# Compare the URDF that ACTUALLY reaches the controller with what the hardware exports.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. did mock mode actually turn on? ##########"
grep -iE "mock mode|enable_mock|serial port|Initialization complete|Failed|error" "$HOME/phase0-mock.log" | head -15 | cut -c1-180 | sed 's/^/  /'

echo
echo "########## 2. the LIVE robot_description's ros2_control block ##########"
timeout 30 ros2 topic echo /robot_description --no-daemon --once > /tmp/rd.txt 2>&1 < /dev/null
echo "  exit=$?  bytes=$(wc -c < /tmp/rd.txt)"
grep -n "ros2_control name\|command_interface\|state_interface\|<hardware>\|</hardware>\|plugin" /tmp/rd.txt | head -30 | cut -c1-170 | sed 's/^/  /'

echo
echo "########## 3. the xacro's command-interface block (context) ##########"
sed -n '540,560p' "$HOME"/ros2_ws/src/so_arm_ros2/so_arm_description/urdf/so101/so101.urdf.xacro | sed 's/^/  /'

echo
echo "########## 4. hardware export logic (cpp) ##########"
sed -n '950,1000p' "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp | sed 's/^/  /'
