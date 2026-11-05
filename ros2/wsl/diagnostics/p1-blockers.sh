#!/usr/bin/env bash
# Two suspects: (1) meshes are Git-LFS pointers -> RViz + MuJoCo broken;
#               (2) emergency stop engaged -> all mock commands are cleared -> no motion.
MESH_DIR="$HOME/ros2_ws/src/so_arm_ros2/so_arm_description/meshes"

echo "########## 1. are the mesh files real STLs or LFS pointers? ##########"
ls -la "$MESH_DIR/so101/" 2>/dev/null | head -6 | sed 's/^/  /'
F="$MESH_DIR/so101/wrist_camera_so101_v1.stl"
echo "  --- first line of $(basename "$F") ---"
head -c 120 "$F" 2>/dev/null | tr -d '\0' | sed 's/^/    /'
echo
echo "  --- any real binary STL (starts with non-zero bytes)? ---"
for f in $(ls "$MESH_DIR/so101/"*.stl 2>/dev/null | head -4); do
  printf "    %-42s %8s bytes  head=%s\n" "$(basename "$f")" "$(stat -c%s "$f")" "$(head -c 5 "$f" | tr -d '\0' | tr -d '\n')"
done
echo
echo "  --- .gitattributes mentions lfs? ---"
grep -iE "lfs|filter" "$HOME/ros2_ws/src/so_arm_ros2/.gitattributes" 2>/dev/null | head -5 | sed 's/^/    /' || echo "    (no .gitattributes or no lfs entries)"
echo "  --- git-lfs installed? ---"
command -v git-lfs >/dev/null && git-lfs version | sed 's/^/    /' || echo "    git-lfs NOT installed"

echo
echo "########## 2. clean up the failed mujoco attempt ##########"
for pat in so_arm_bringup ros2_control_node controller_manager/spawner so_arm_control/lib \
           so_arm_bringup/lib teleop_ik_node record_replay_node joy_teleop \
           joint_trajectory_bridge teleop_support_node robot_state_publisher mujoco; do
  pkill -9 -f -- "$pat" 2>/dev/null
done
sleep 4
echo "  leftover: $(ps -eo cmd | grep -cE '[s]o_arm|[c]ontroller_manager|[m]ujoco')"

echo
echo "########## 3. restart in MOCK mode and check the emergency-stop state ##########"
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
LOG="$HOME/phase0-mock.log"; rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py use_mock:=true wrist_camera:=false > "$LOG" 2>&1 &
sleep 35
echo "  --- controllers ---"
timeout 25 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers > /tmp/mc2.txt 2>&1 < /dev/null
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/mc2.txt | sed 's/^/    /'
echo "  --- emergency stop state ---"
timeout 15 ros2 topic echo /emergency_stop_active --no-daemon --once 2>&1 < /dev/null | head -6 | sed 's/^/    /'
echo "  --- e-stop service available? ---"
timeout 20 ros2 service list --no-daemon 2>/dev/null | grep -i emerg | sed 's/^/    /' || echo "    (none listed)"
