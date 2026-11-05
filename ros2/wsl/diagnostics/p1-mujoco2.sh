#!/usr/bin/env bash
# Try MuJoCo without the ASCII-STL wrist-camera mesh: wrist_camera_urdf:=false.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

sample() {
  timeout 15 ros2 topic echo /joint_states --no-daemon --once > /tmp/s2.txt 2>&1 < /dev/null
  python3 - <<'PY'
import re
t = open('/tmp/s2.txt', errors='ignore').read()
head, _, tail = t.partition('position:')
names = re.findall(r"^- (\w+)$", head, re.M)
pos = [float(p) for p in re.findall(r"^- (-?[\d.eE+-]+)$", tail, re.M)[:len(names)]]
print("    ", {k: round(v, 4) for k, v in zip(names, pos)})
PY
}

echo "########## clean ##########"
for pat in so_arm_bringup ros2_control_node controller_manager/spawner so_arm_control/lib \
           so_arm_bringup/lib teleop_ik_node record_replay_node joy_teleop \
           joint_trajectory_bridge teleop_support_node robot_state_publisher mujoco; do
  pkill -9 -f -- "$pat" 2>/dev/null
done
sleep 4

echo "########## launch: mujoco + wrist_camera_urdf:=false ##########"
LOG="$HOME/phase1-mujoco2.log"; rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py ros2_control_hardware_type:=mujoco \
  wrist_camera_urdf:=false wrist_camera:=false mujoco_headless:=false > "$LOG" 2>&1 &
echo "  pid $! ; settling 45 s"
sleep 45

echo "  --- MuJoCo loaded? ---"
grep -iE "mujoco" "$LOG" | grep -iE "load|error|fatal|fail|model" | head -6 | cut -c1-190 | sed 's/^/    /'

echo "  --- controllers ---"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/mc3.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/mc3.txt | sed 's/^/    /'

echo "  --- state before ---"
sample

echo "  --- command shoulder_pan -> -0.30 ---"
timeout 25 ros2 topic pub --once /joint_commands sensor_msgs/msg/JointState \
  "{name: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'], position: [-0.30, 0.0, 0.0, 0.0, 0.0, 0.0]}" \
  > /dev/null 2>&1 < /dev/null
sleep 2; echo "  after 2 s:";  sample
sleep 3; echo "  after 5 s:";  sample

echo
echo "  --- log tail ---"
tail -8 "$LOG" | cut -c1-180 | sed 's/^/    /'
