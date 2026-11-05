#!/usr/bin/env bash
# Safe ROS CLI diagnosis: never pipe a ros2 command (its spawned daemon inherits stdout
# and holds the pipe open). Everything goes to files; the outer caller caps total time.

echo "########## 0. clean up any orphaned ros2 processes ##########"
pkill -f "ros2 daemon" 2>/dev/null
pkill -f "ros2_daemon" 2>/dev/null
sleep 1
echo "  remaining ros2 procs: $(pgrep -fc ros2 2>/dev/null || echo 0)"

source /opt/ros/jazzy/setup.bash
echo "  ROS_DISTRO=[${ROS_DISTRO}]"

echo
echo "########## A. ros2 pkg list (needs no daemon) ##########"
unset ROS_AUTOMATIC_DISCOVERY_RANGE ROS_LOCALHOST_ONLY
timeout 60 ros2 pkg list > /tmp/a.txt 2> /tmp/a.err < /dev/null
echo "  exit=$?  lines=$(wc -l < /tmp/a.txt)"
echo "  stderr: $(head -c 200 /tmp/a.err | tr '\n' ' ')"

echo
echo "########## B. ros2 topic list, discovery var UNSET ##########"
ros2 daemon stop > /dev/null 2>&1
sleep 1
timeout 60 ros2 topic list > /tmp/b.txt 2> /tmp/b.err < /dev/null
echo "  exit=$?  output: $(tr '\n' ' ' < /tmp/b.txt)"
echo "  stderr: $(head -c 200 /tmp/b.err | tr '\n' ' ')"

echo
echo "########## C. ros2 topic list, ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST ##########"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
ros2 daemon stop > /dev/null 2>&1
sleep 1
timeout 60 ros2 topic list > /tmp/c.txt 2> /tmp/c.err < /dev/null
echo "  exit=$?  output: $(tr '\n' ' ' < /tmp/c.txt)"
echo "  stderr: $(head -c 200 /tmp/c.err | tr '\n' ' ')"

echo
echo "########## D. persist for non-interactive login shells ##########"
grep -q 'ROS_AUTOMATIC_DISCOVERY_RANGE' "$HOME/.profile" 2>/dev/null \
  || echo 'export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST' >> "$HOME/.profile"
tail -3 "$HOME/.profile" | sed 's/^/    /'
echo "  (~/.bashrc returns early when non-interactive, so .profile is where scripts pick it up)"
