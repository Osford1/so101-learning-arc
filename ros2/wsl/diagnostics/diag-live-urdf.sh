#!/usr/bin/env bash
# Which xacro args does the launch actually pass, and what does the runtime URDF contain?
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. FULL urdf_config.yaml ##########"
cat "$HOME/ros2_ws/src/so_arm_ros2/so_arm_control/config/urdf_config.yaml" | sed 's/^/  /'

echo
echo "########## 2. the launch's xacro command construction ##########"
sed -n '40,85p' "$HOME/ros2_ws/src/so_arm_ros2/so_arm_control/launch/control.launch.py" | sed 's/^/  /'

echo
echo "########## 3. the RUNTIME robot_description: interface counts ##########"
timeout 30 ros2 topic echo /robot_description --no-daemon --once > /tmp/live.txt 2>&1 < /dev/null
echo "  bytes=$(wc -c < /tmp/live.txt)"
echo "  position cmd: $(grep -c '<command_interface name="position"/>' /tmp/live.txt)"
echo "  velocity cmd: $(grep -c '<command_interface name="velocity"/>' /tmp/live.txt)"
echo "  effort   cmd: $(grep -c '<command_interface name="effort"/>' /tmp/live.txt)"
echo "  operating_mode params in live URDF:"; grep -o '<param name="operating_mode">[0-9]*</param>' /tmp/live.txt | sort | uniq -c | sed 's/^/    /'
echo "  --- the live hardware block ---"
sed -n '/<hardware>/,/<\/hardware>/p' /tmp/live.txt | head -12 | sed 's/^/    /'
