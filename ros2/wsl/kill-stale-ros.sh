#!/usr/bin/env bash
# Kill leftovers from the purged stack, then find out whether the ros2 CLI daemon can be fixed.

source /opt/ros/jazzy/setup.bash
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## 1. everything ROS-ish that's alive ##########"
ps -eo pid,etimes,cmd | grep -iE "ros2|controller_manager|demo_nodes|talker|listener" | grep -vE "grep|diag-daemon|bash -lc" | cut -c1-150 | sed 's/^/  /'

echo
echo "########## 2. killing leftovers from the purged old stack ##########"
for pat in "so_arm101_description" "so101_ws" "ros2_control_node" "demo_nodes" "topic echo" "controller_manager"; do
  n=$(pgrep -fc -- "$pat" 2>/dev/null || echo 0)
  pkill -9 -f -- "$pat" 2>/dev/null
  echo "  $pat -> killed $n"
done
sleep 2
echo "  still alive:"
ps -eo pid,cmd | grep -iE "ros2|controller_manager|demo_nodes" | grep -vE "grep|diag-daemon|bash -lc" | cut -c1-120 | sed 's/^/    /' || echo "    (none)"

echo
echo "########## 3. any CLI daemon left? (broader pattern) ##########"
pgrep -af "daemon" | head -5 | sed 's/^/  /' || echo "  none"
echo "  ~/.ros: $(ls -a "$HOME/.ros" 2>/dev/null | tr '\n' ' ')"
echo "  sockets/ports owned by python:"
ss -tlnp 2>/dev/null | grep -i python | head -5 | sed 's/^/    /' || echo "    none"

echo
echo "########## 4. can the daemon be disabled by env var? ##########"
grep -rln "NO_DAEMON\|no_daemon" /opt/ros/jazzy/lib/python3.12/site-packages/ros2cli/ 2>/dev/null | head -5
grep -rn "add_argument.*no-daemon\|'--no-daemon'\|\"--no-daemon\"" /opt/ros/jazzy/lib/python3.12/site-packages/ros2cli/ 2>/dev/null | head -3 | cut -c1-160

echo
echo "########## 5. daemon path retest after cleanup ##########"
timeout 40 ros2 topic list > /tmp/d1.txt 2>&1 < /dev/null
echo "  exit=$?  out=[$(tr '\n' ' ' < /tmp/d1.txt)]"

echo
echo "########## 6. --no-daemon path, same conditions ##########"
timeout 40 ros2 topic list --no-daemon > /tmp/d2.txt 2>&1 < /dev/null
echo "  exit=$?  out=[$(tr '\n' ' ' < /tmp/d2.txt)]"
