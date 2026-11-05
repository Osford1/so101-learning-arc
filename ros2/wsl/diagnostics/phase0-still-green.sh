#!/usr/bin/env bash
# Confirm the gate is still green on the stack that's been running a while.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "=== controller states ==="
timeout 25 ros2 service call /controller_manager/list_controllers \
  controller_manager_msgs/srv/ListControllers > /tmp/c_final.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/c_final.txt | sed 's/^/  /'

echo "=== /joint_states still flowing? ==="
timeout 20 ros2 topic hz /joint_states --no-daemon > /tmp/hz.txt 2>&1 < /dev/null &
HZPID=$!
sleep 12
kill $HZPID 2>/dev/null
grep -iE "average rate|no new messages" /tmp/hz.txt | head -2 | sed 's/^/  /'

echo "=== stack uptime (launch process) ==="
ps -eo etimes,cmd | grep "[s]o_arm.launch.py" | awk '{printf "  launch running %s min\n", int($1/60)}'
