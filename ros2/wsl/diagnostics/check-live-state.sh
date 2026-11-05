#!/usr/bin/env bash
# What is actually running, and which topics exist?
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## processes ##########"
ps -eo pid,etimes,cmd | grep -E "[c]ontroller_manager|[s]o_arm|[t]eleop|robot_state_pub" | cut -c1-110 | sed 's/^/  /'
echo
echo "########## launch processes ##########"
ps -eo pid,etimes,cmd | grep "[s]o_arm.launch.py" | cut -c1-110 | sed 's/^/  /' || echo "  (no launch running)"

echo
echo "########## topic list ##########"
timeout 25 ros2 topic list --no-daemon 2>&1 < /dev/null | sed 's/^/  /'

echo
echo "########## node list ##########"
timeout 25 ros2 node list --no-daemon 2>&1 < /dev/null | sed 's/^/  /'

echo
echo "########## controllers ##########"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/lc.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/lc.txt | sed 's/^/  /' || tail -3 /tmp/lc.txt | sed 's/^/  /'
