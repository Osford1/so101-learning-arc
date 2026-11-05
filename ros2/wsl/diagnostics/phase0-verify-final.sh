#!/usr/bin/env bash
# Final Phase 0 evidence: all nodes alive, interfaces, joint values, no errors.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
LOG="$HOME/phase0-mock.log"

echo "########## 1. nodes alive ##########"
ps -eo pid,cmd | grep -E "lib/(so_arm|controller_manager|joy)|ros2 launch" | grep -vE "grep|bash -lc" | sed 's/.*\///' | cut -c1-70 | sort | uniq | sed 's/^/  /'

echo
echo "########## 2. is the trajectory bridge still alive (it died before)? ##########"
pgrep -af "joint_trajectory_bridge" | cut -c1-90 | sed 's/^/  /' || echo "  NOT running"
echo "  --- its log lines ---"
grep -iE "joint_trajectory_bridge" "$LOG" | tail -6 | cut -c1-200 | sed 's/^/    /'

echo
echo "########## 3. did the IK node get its model? ##########"
grep -iE "teleop_ik_node" "$LOG" | grep -iE "IK model|failed" | tail -4 | cut -c1-200 | sed 's/^/  /'

echo
echo "########## 4. command interfaces now available ##########"
timeout 25 ros2 service call /controller_manager/list_hardware_interfaces \
  controller_manager_msgs/srv/ListHardwareInterfaces > /tmp/hwi2.txt 2>&1 < /dev/null
echo "  position cmd ifaces: $(grep -o "command_interfaces=\[[^]]*\]" /tmp/hwi2.txt | grep -o "position'" | wc -l)"
echo "  velocity cmd ifaces: $(grep -o "command_interfaces=\[[^]]*\]" /tmp/hwi2.txt | grep -o "velocity'" | wc -l)"
grep -o "name='[a-z_]*/velocity', data_type='double', is_available=[A-Za-z]*" /tmp/hwi2.txt | head -6 | sed 's/^/    /'

echo
echo "########## 5. /joint_states values ##########"
timeout 25 ros2 topic echo /joint_states --no-daemon --once > /tmp/js2.txt 2>&1 < /dev/null
sed -n '/^name:/,/^---/p' /tmp/js2.txt | head -20 | sed 's/^/  /'

echo
echo "########## 6. any remaining ERROR in the log? ##########"
grep -E "ERROR" "$LOG" | grep -v "FIFO RT" | tail -5 | cut -c1-190 | sed 's/^/  /' || echo "  (none)"
echo
echo "########## 7. launch + node count ##########"
timeout 25 ros2 node list --no-daemon 2>&1 < /dev/null | sed 's/^/  /'
