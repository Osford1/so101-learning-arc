#!/usr/bin/env bash
# ============================================================================
#  Phase 0 gate — SO-101 on ROS 2 Jazzy (so_arm_ros2 stack), mock mode.
#  Kills any leftover stack processes first: a stale publisher's
#  /robot_description will make the new stack load the WRONG description and
#  the controller will refuse to activate. This bit me once; never again.
#  Stop the stack afterwards with:  pkill -f "so_arm_bringup"
# ============================================================================
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST      # required under WSL mirrored networking

echo "########## 0. clean slate ##########"
for pat in so_arm_bringup ros2_control_node controller_manager/spawner \
           so_arm_control/lib so_arm_bringup/lib teleop_ik_node record_replay_node \
           joy_teleop joint_trajectory_bridge teleop_support_node target_visualizer \
           bool_toggle_node joint_state_switch_node robot_state_publisher \
           sts_hardware_interface; do
  pkill -9 -f -- "$pat" 2>/dev/null
done
sleep 3
left=$(ps -eo cmd | grep -cE "[s]o_arm|[c]ontroller_manager|[r]obot_state_publisher")
echo "  leftover ROS processes: $left (0 is what you want)"

echo
echo "########## 1. launch (mock: no hardware, no serial port) ##########"
LOG="$HOME/phase0-mock.log"; rm -f "$LOG"
nohup ros2 launch so_arm_bringup so_arm.launch.py use_mock:=true wrist_camera:=false > "$LOG" 2>&1 &
echo "  pid $!  ->  log: $LOG"
echo "  waiting up to 120 s for controllers to activate..."

for i in $(seq 1 24); do
  sleep 5
  timeout 20 ros2 service call /controller_manager/list_controllers \
    controller_manager_msgs/srv/ListControllers > /tmp/ctl.txt 2>&1 < /dev/null
  grep -q "state='active'" /tmp/ctl.txt 2>/dev/null && break
done

echo
echo "########## GATE EVIDENCE ##########"
echo "--- controllers (expect joint_state_broadcaster + so_arm_controller, both 'active') ---"
grep -o "name='[a-z_]*'[^)]*state='[a-z]*'" /tmp/ctl.txt | sed 's/^/  /'

echo "--- command interfaces (expect 6 position + 6 velocity) ---"
timeout 25 ros2 service call /controller_manager/list_hardware_interfaces \
  controller_manager_msgs/srv/ListHardwareInterfaces > /tmp/hwi.txt 2>&1 < /dev/null
echo "  position: $(grep -o "command_interfaces=\[[^]]*\]" /tmp/hwi.txt | grep -o "position'" | wc -l)"
echo "  velocity: $(grep -o "command_interfaces=\[[^]]*\]" /tmp/hwi.txt | grep -o "velocity'" | wc -l)"

echo "--- nodes ---"
timeout 25 ros2 node list --no-daemon 2>&1 < /dev/null | grep -v WARNING | sed 's/^/  /'

echo "--- /joint_states (one message, 6 joints) ---"
timeout 25 ros2 topic echo /joint_states --no-daemon --once > /tmp/js.txt 2>&1 < /dev/null
sed -n '/^name:/,/^---/p' /tmp/js.txt | head -18 | sed 's/^/  /'

echo
echo "--- mock mode confirmed in the hardware's log ---"
grep -iE "Mock mode enabled|Initialization complete" "$LOG" | cut -c1-150 | sed 's/^/  /'

echo
echo "--- any controller errors? ---"
grep -iE "Failed to activate|Unable to activate|Could not configure|process has died" "$LOG" \
  | cut -c1-170 | sed 's/^/  /' || echo "  (none)"

echo
echo "########## notes ##########"
echo "  * ros2 CLI daemon HANGS on this host: use 'ros2 topic list --no-daemon',"
echo "    'ros2 node list --no-daemon'; and 'ros2 control <verb>' does not accept --no-daemon,"
echo "    so query the controller_manager with 'ros2 service call' (as this script does)."
echo "  * The stack is left RUNNING. Stop it:  pkill -f so_arm_bringup"
echo "  * Visualise: rviz2  ->  add a RobotModel display, topic /robot_description"
