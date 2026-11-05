#!/usr/bin/env bash
# Isolate the hang: daemon vs DDS discovery. Uses --no-daemon to bypass the CLI daemon.

echo "########## 0. what ros2 processes are alive? ##########"
ps -eo pid,etimes,cmd | grep -iE "ros2|_daemon" | grep -vE "grep|bash -lc|fix-ros2" | head -8

echo
echo "########## 1. kill orphaned daemons (targeted) ##########"
pkill -9 -f "_ros2_daemon" 2>/dev/null; pkill -9 -f "ros2cli.daemon" 2>/dev/null; pkill -9 -f "ros2 daemon" 2>/dev/null
sleep 2
echo "  after: $(ps -eo cmd | grep -c "[r]os2_daemon") daemon procs"
echo "  ~/.ros contents:"; ls -a "$HOME/.ros" 2>/dev/null | head -8 | sed 's/^/    /'

source /opt/ros/jazzy/setup.bash

echo
echo "########## 2. --no-daemon, discovery var UNSET ##########"
unset ROS_AUTOMATIC_DISCOVERY_RANGE
timeout 45 ros2 topic list --no-daemon > /tmp/n1.txt 2> /tmp/n1.err < /dev/null
echo "  exit=$?  out=[$(tr '\n' ' ' < /tmp/n1.txt)]"
echo "  err=[$(head -c 200 /tmp/n1.err | tr '\n' ' ')]"

echo
echo "########## 3. --no-daemon, ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST ##########"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
timeout 45 ros2 topic list --no-daemon > /tmp/n2.txt 2> /tmp/n2.err < /dev/null
echo "  exit=$?  out=[$(tr '\n' ' ' < /tmp/n2.txt)]"
echo "  err=[$(head -c 200 /tmp/n2.err | tr '\n' ' ')]"

echo
echo "########## 4. daemon path, LOCALHOST ##########"
timeout 45 ros2 topic list > /tmp/n3.txt 2> /tmp/n3.err < /dev/null
echo "  exit=$?  out=[$(tr '\n' ' ' < /tmp/n3.txt)]"
echo "  err=[$(head -c 200 /tmp/n3.err | tr '\n' ' ')]"
