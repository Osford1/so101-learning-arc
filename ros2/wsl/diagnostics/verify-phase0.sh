#!/usr/bin/env bash
# Post-install verification + fix the missing SCServo_Linux submodule.
source /opt/ros/jazzy/setup.bash
echo "########## ROS 2 core ##########"
echo "  ros2 at: $(command -v ros2)"
echo "  rosdistro: $(printenv ROS_DISTRO)"
echo "  package count: $(ros2 pkg list 2>/dev/null | wc -l)"
echo "  ros2 topic list ->"
ros2 topic list 2>&1 | sed 's/^/    /'
echo
echo "########## sts_hardware_interface: submodule state ##########"
cd "$HOME/ros2_ws/src/sts_hardware_interface" || exit 1
echo "  .gitmodules:"; sed 's/^/    /' .gitmodules 2>&1
echo "  external/ contents:"; ls -la external/ 2>&1 | sed 's/^/    /' | head -8
echo "  submodule status:"; git submodule status 2>&1 | sed 's/^/    /'
echo
echo "########## does the build actually need SCServo_Linux? ##########"
grep -rn "SCServo\|external/" --include=CMakeLists.txt . 2>/dev/null | head -12 | sed 's/^/    /'
echo
echo "########## attempting submodule fetch (with proxy) ##########"
git -c http.proxy=http://127.0.0.1:PORT -c https.proxy=http://127.0.0.1:PORT submodule update --init --recursive 2>&1 | tail -8
echo "  exit: $?"
echo "  external/ after:"; ls external/ 2>&1 | sed 's/^/    /'
