#!/usr/bin/env bash
# Why doesn't the mock move? And does MuJoCo mode actually move the arm?
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. what the mock does on read (why state is static) ##########"
sed -n '1025,1050p' "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp | sed 's/^/  /'
echo "  --- and on write ---"
sed -n '1210,1225p' "$HOME"/ros2_ws/src/sts_hardware_interface/src/sts_hardware_interface.cpp | sed 's/^/  /'

echo
echo "########## 2. stop the mock stack ##########"
pkill -9 -f "so_arm_bringup" 2>/dev/null
pkill -9 -f "so_arm_control/lib" 2>/dev/null
pkill -9 -f "controller_manager" 2>/dev/null
pkill -9 -f "robot_state_publisher" 2>/dev/null
sleep 4
echo "  leftover: $(ps -eo cmd | grep -cE '[s]o_arm|[c]ontroller_manager')"

echo
echo "########## 3. launch in MuJoCo mode (real physics) ##########"
LOG="$HOME/phase1-mujoco.log"; rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py ros2_control_hardware_type:=mujoco \
  mujoco_headless:=false wrist_camera:=false > "$LOG" 2>&1 &
echo "  pid $!  settling 45 s (physics + viewer)"
sleep 45

echo "  --- controllers ---"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/mc.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/mc.txt | sed 's/^/    /'

echo "  --- startup errors? ---"
grep -iE "error|failed|not found|died" "$LOG" | grep -viE "FIFO RT|log-level" | head -8 | cut -c1-170 | sed 's/^/    /'

echo
echo "########## 4. command a move and see whether physics moves the arm ##########"
timeout 20 ros2 topic echo /joint_states --no-daemon --once > /tmp/mb.txt 2>&1 < /dev/null
echo "  BEFORE:"; grep -A 8 "^name:" /tmp/mb.txt | tail -6 | sed 's/^/    /'
timeout 25 ros2 topic pub --once /joint_commands sensor_msgs/msg/JointState \
  "{name: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'], position: [-0.25, 0.0, 0.0, 0.0, 0.0, 0.0]}" \
  > /dev/null 2>&1 < /dev/null
sleep 5
timeout 20 ros2 topic echo /joint_states --no-daemon --once > /tmp/ma.txt 2>&1 < /dev/null
echo "  AFTER 5 s:"; grep -A 8 "^name:" /tmp/ma.txt | tail -6 | sed 's/^/    /'

echo
echo "########## 5. log tail ##########"
tail -12 "$LOG" | cut -c1-180 | sed 's/^/  /'
