#!/usr/bin/env bash
# What params does the URDF emit to the hardware, and how does the C++ parse them?

echo "########## 1. the <hardware> block of the generated URDF ##########"
sed -n '/<ros2_control name=/,/<joint name="shoulder_pan_joint"/p' /tmp/gen.urdf | head -40 | sed 's/^/  /'

echo
echo "########## 2. one joint's interface declarations (first joint in ros2_control) ##########"
awk '/<ros2_control name=/{f=1} f' /tmp/gen.urdf | grep -n -A 8 '<joint name="shoulder_pan_joint"' | head -20 | sed 's/^/  /'

echo
echo "########## 3. how does the hardware parse operating modes / readonly / velocity? ##########"
grep -n "operating_mode\|is_readonly_\|parse_int_param\|hw_cmd_velocity_\|MODE_SERVO\|MODE_VELOCITY" \
  "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp | head -30 | cut -c1-150 | sed 's/^/  /'

echo
echo "########## 4. live interface list via the controller_manager service ##########"
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
timeout 30 ros2 service call /controller_manager/list_hardware_interfaces \
  controller_manager_msgs/srv/ListHardwareInterfaces > /tmp/svc.txt 2>&1 < /dev/null
echo "  exit=$?  bytes=$(wc -c < /tmp/svc.txt)"
head -40 /tmp/svc.txt | sed 's/^/  /'
