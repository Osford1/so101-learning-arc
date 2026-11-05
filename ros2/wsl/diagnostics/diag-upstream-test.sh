#!/usr/bin/env bash
export HTTPS_PROXY=http://127.0.0.1:PORT HTTP_PROXY=http://127.0.0.1:PORT
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. RUNTIME robot_description interface counts ##########"
timeout 30 ros2 topic echo /robot_description --no-daemon --once > /tmp/live.txt 2>&1 < /dev/null
echo "  bytes=$(wc -c < /tmp/live.txt)"
echo "  position cmd: $(grep -c '<command_interface name=\"position\"/>' /tmp/live.txt)"
echo "  velocity cmd: $(grep -c '<command_interface name=\"velocity\"/>' /tmp/live.txt)"
echo "  operating_mode params:"; grep -o '<param name="operating_mode">[0-9]*</param>' /tmp/live.txt | sort | uniq -c | sed 's/^/    /'
echo "  --- live hardware block ---"; sed -n '/<hardware>/,/<\/hardware>/p' /tmp/live.txt | head -10 | sed 's/^/    /'

echo
echo "########## 2. does upstream's own Jazzy test expect the controller to ACTIVATE? ##########"
curl -s --max-time 60 "https://raw.githubusercontent.com/adityakamath/so_arm_ros2/main/so_arm_control/test/test_control_launch.py" > /tmp/tcl.py
echo "  bytes=$(wc -c < /tmp/tcl.py)"
grep -nE "use_mock|active|list_controllers|assert|def test" /tmp/tcl.py | head -25 | cut -c1-150 | sed 's/^/  /'

echo
echo "########## 3. which sts_hardware_interface commit am I on? ##########"
cd "$HOME/ros2_ws/src/sts_hardware_interface" && git log -1 --format='  %h %ad %s' --date=short
cd "$HOME/ros2_ws/src/so_arm_ros2" && git log -1 --format='  so_arm_ros2: %h %ad %s' --date=short
