#!/usr/bin/env bash
# Verify the saved RViz config loads cleanly against the mock stack.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

cp "$(dirname "${BASH_SOURCE[0]}")/../../so_arm.rviz" "$HOME/so_arm.rviz"
echo "config copied: $(wc -l < "$HOME/so_arm.rviz") lines"

echo
echo "########## is a stack up? ##########"
alive=$(ps -eo cmd | grep -cE "[c]ontroller_manager/ros2_control_node")
echo "  ros2_control_node running: $alive"
if [ "$alive" = "0" ]; then
  echo "  starting mock stack..."
  nohup ros2 launch so_arm_bringup so_arm.launch.py use_mock:=true wrist_camera:=false > "$HOME/phase0-mock.log" 2>&1 &
  sleep 35
fi

echo
echo "########## launching rviz2 with the saved config ##########"
LOG="$HOME/rviz.log"; rm -f "$LOG"
nohup rviz2 -d "$HOME/so_arm.rviz" > "$LOG" 2>&1 &
RV=$!
echo "  rviz pid $RV ; waiting 25 s"
sleep 25

echo "  --- still running? ---"
if kill -0 "$RV" 2>/dev/null; then echo "    yes, pid $RV alive (window should be on screen)"; else echo "    NO - it exited"; fi

echo "  --- config / display problems reported by rviz2 ---"
grep -iE "error|fail|invalid|could not|no such|unknown|warning" "$LOG" | head -12 | cut -c1-180 | sed 's/^/    /' || echo "    (none)"

echo "  --- first lines of rviz log ---"
head -6 "$LOG" | cut -c1-170 | sed 's/^/    /'

echo
echo "########## closing the test instance (it was mine, not yours) ##########"
kill "$RV" 2>/dev/null; sleep 3
echo "  rviz running now: $(ps -eo cmd | grep -c '[r]viz2')"
