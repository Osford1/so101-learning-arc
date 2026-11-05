#!/usr/bin/env bash
# Sim attempt 3 — file name deliberately avoids the process patterns it kills.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

sample() {
  timeout 15 ros2 topic echo /joint_states --no-daemon --once > /tmp/s3.txt 2>&1 < /dev/null
  python3 - <<'PY'
import re
t = open('/tmp/s3.txt', errors='ignore').read()
head, _, tail = t.partition('position:')
names = re.findall(r"^- (\w+)$", head, re.M)
pos = [float(p) for p in re.findall(r"^- (-?[\d.eE+-]+)$", tail, re.M)[:len(names)]]
print("    ", {k: round(v, 4) for k, v in zip(names, pos)})
PY
}

echo "########## clean (bracketed patterns so this script survives) ##########"
for pat in "[s]o_arm_bringup" "[r]os2_control_node" "[c]ontroller_manager/spawner" \
           "[s]o_arm_control/lib" "[s]o_arm_bringup/lib" "[t]eleop_ik_node" \
           "[r]ecord_replay_node" "[j]oy_teleop" "[j]oint_trajectory_bridge" \
           "[t]eleop_support_node" "[r]obot_state_publisher" "[m]ujoco_ros2_control"; do
  pkill -9 -f -- "$pat" 2>/dev/null
done
sleep 4
echo "  leftover: $(ps -eo cmd | grep -cE '[s]o_arm|[c]ontroller_manager|[m]ujoco')"

echo
echo "########## launch: MuJoCo, camera mesh excluded ##########"
LOG="$HOME/phase1-sim.log"; rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py ros2_control_hardware_type:=mujoco \
  wrist_camera_urdf:=false wrist_camera:=false mujoco_headless:=false > "$LOG" 2>&1 &
echo "  pid $! ; settling 50 s"
sleep 50

echo "  --- MuJoCo model load status ---"
grep -iE "mujoco" "$LOG" | grep -iE "load|error|fatal|fail|model|mesh" | head -6 | cut -c1-190 | sed 's/^/    /'

echo "  --- controllers ---"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/mc4.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/mc4.txt | sed 's/^/    /'

echo "  --- state before ---"; sample
echo "  --- command shoulder_pan -> -0.30 ---"
timeout 25 ros2 topic pub --once /joint_commands sensor_msgs/msg/JointState \
  "{name: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'], position: [-0.30, 0.0, 0.0, 0.0, 0.0, 0.0]}" \
  > /dev/null 2>&1 < /dev/null
sleep 2; echo "  after 2 s:"; sample
sleep 3; echo "  after 5 s:"; sample

echo
echo "  --- log tail ---"
tail -8 "$LOG" | cut -c1-180 | sed 's/^/    /'
