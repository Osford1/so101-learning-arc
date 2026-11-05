#!/usr/bin/env bash
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## /joint_commands endpoints (who publishes, who subscribes) ##########"
timeout 25 ros2 topic info /joint_commands --no-daemon -v > /tmp/jc.txt 2>&1 < /dev/null
grep -E "Type:|Publisher count|Subscription count|Node name|Endpoint type" /tmp/jc.txt | sed 's/^/  /'

echo
echo "########## the switch node's own connections ##########"
timeout 25 ros2 node info /joint_state_switch_node --no-daemon > /tmp/sw.txt 2>&1 < /dev/null
sed -n '1,40p' /tmp/sw.txt | sed 's/^/  /'
