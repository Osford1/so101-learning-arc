#!/usr/bin/env bash
# What the ros2 CLI daemon is, on THIS machine.
source /opt/ros/jazzy/setup.bash
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

SP=/opt/ros/jazzy/lib/python3.12/site-packages/ros2cli/node/strategy.py

echo "########## 1. the flag's documentation (from the installed source) ##########"
grep -n -B 3 -A 4 "no-daemon" "$SP" | cut -c1-160 | sed 's/^/  /'

echo
echo "########## 2. is there an env var that disables the daemon? ##########"
grep -n "environ\|NO_DAEMON" "$SP" | cut -c1-160 | sed 's/^/  /' || echo "  (no env-var path found in strategy.py)"

echo
echo "########## 3. ros2 daemon subcommands ##########"
timeout 20 ros2 daemon --help 2>&1 | head -14 | sed 's/^/  /'

echo
echo "########## 4. is a daemon process alive right now? ##########"
ps -eo pid,etimes,cmd | grep "[_]ros2_daemon" | cut -c1-120 | sed 's/^/  /' || echo "  none"

echo
echo "########## 5. timing: --no-daemon (direct discovery) ##########"
time ( timeout 40 ros2 topic list --no-daemon > /tmp/nd.txt 2>&1 < /dev/null )
echo "  topics found: $(wc -l < /tmp/nd.txt)"

echo
echo "########## 6. timing: default path (via the daemon) ##########"
time ( timeout 40 ros2 topic list > /tmp/dd.txt 2>&1 < /dev/null )
echo "  exit=$?  topics found: $(wc -l < /tmp/dd.txt)"
