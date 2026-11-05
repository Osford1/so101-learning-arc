#!/usr/bin/env bash
# Real numbers for teaching: what /joint_states actually is (type, QoS, rate, participants).
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## topic info (verbose: type, participants, QoS) ##########"
timeout 25 ros2 topic info /joint_states --no-daemon -v > /tmp/ti.txt 2>&1 < /dev/null
cat /tmp/ti.txt | sed 's/^/  /'

echo
echo "########## publish rate ##########"
timeout 14 ros2 topic hz /joint_states --no-daemon > /tmp/hz.txt 2>&1 < /dev/null
grep -iE "average rate|min|max|window" /tmp/hz.txt | head -4 | sed 's/^/  /'

echo
echo "########## the command-side topics, for contrast ##########"
for t in /joint_commands /so_arm_controller/joint_trajectory; do
  echo "  --- $t ---"
  timeout 20 ros2 topic info "$t" --no-daemon > /tmp/t2.txt 2>&1 < /dev/null
  grep -E "Type|Publisher count|Subscription count" /tmp/t2.txt | sed 's/^/    /'
done

echo
echo "########## how many topics exist on this robot right now? ##########"
timeout 20 ros2 topic list --no-daemon 2>/dev/null | wc -l | sed 's/^/  total topics: /'
