#!/usr/bin/env bash
# Full clean cycle: kill EVERYTHING ros2, relaunch once, dump untruncated errors.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. hard cleanup ##########"
for pat in "so_arm_bringup" "ros2_control_node" "controller_manager/spawner" "joint_state_broadcaster" "so_arm_controller" "teleop_ik_node" "record_replay_node" "joy_teleop" "joint_trajectory_bridge" "teleop_support_node"; do
  pkill -9 -f -- "$pat" 2>/dev/null
done
sleep 3
echo "  survivors:"; ps -eo pid,cmd | grep -iE "controller_manager|so_arm|teleop|joy_teleop" | grep -vE "grep|bash -lc" | cut -c1-100 | sed 's/^/    /' || true
echo "  (empty = clean)"

echo
echo "########## 2. launch ##########"
LOG="$HOME/phase0-mock.log"
rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py use_mock:=true wrist_camera:=false > "$LOG" 2>&1 &
LPID=$!
echo "  pid $LPID; settling 40 s"
sleep 40

echo
echo "########## 3. every controller_manager complaint, UNTRUNCATED ##########"
grep -nE "controller_manager\]" "$LOG" | grep -iE "configure|activate|claim|interface|available|error|warn" | cut -c1-260 | sed 's/^/  /'

echo
echo "########## 4. spawner outcomes ##########"
grep -nE "spawner" "$LOG" | tail -12 | cut -c1-220 | sed 's/^/  /'

echo
echo "########## 5. controller states ##########"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/ctl2.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/ctl2.txt | sed 's/^/  /' || tail -5 /tmp/ctl2.txt | sed 's/^/  /'

echo
echo "########## 6. is robot_description actually populated? ##########"
timeout 25 ros2 topic echo /robot_description --no-daemon --once > /tmp/rd2.txt 2>&1 < /dev/null
echo "  bytes=$(wc -c < /tmp/rd2.txt)  velocity cmd ifaces=$(grep -c 'name=\"velocity\"' /tmp/rd2.txt)"
head -3 /tmp/rd2.txt | cut -c1-120 | sed 's/^/  /'

echo
echo "########## 7. robot_state_publisher log ##########"
grep -iE "robot_state_publisher" "$LOG" | head -6 | cut -c1-220 | sed 's/^/  /'
