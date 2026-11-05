#!/usr/bin/env bash
# Kill orphaned robot_state_publishers from earlier launches (keep the newest = current run),
# then confirm the graph is clean.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## robot_state_publisher instances (pid, uptime s) ##########"
ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" | awk '{printf "  pid=%s uptime=%ss\n", $1, $2}'

echo
echo "########## killing ones older than 200 s (orphans from earlier launches) ##########"
ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" | awk '$2 > 200 {print $1}' | while read -r p; do
  echo "  killing $p"; kill -9 "$p" 2>/dev/null
done
sleep 3

echo
echo "########## remaining publishers ##########"
ps -eo pid,etimes,cmd | grep "[r]obot_state_publisher" | awk '{printf "  pid=%s uptime=%ss\n", $1, $2}'

echo
echo "########## node graph now ##########"
timeout 25 ros2 node list --no-daemon 2>&1 < /dev/null | sed 's/^/  /'

echo
echo "########## controllers still active after cleanup? ##########"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/c3.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/c3.txt | sed 's/^/  /'

echo
echo "########## harden the gate script's cleanup list for next time ##########"
grep -n "robot_state_publisher" "$HOME/phase0-gate.sh" 2>/dev/null || echo "  (guard: gate script will be updated on the Windows side)"
