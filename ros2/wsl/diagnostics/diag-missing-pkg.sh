#!/usr/bin/env bash
# What package is missing, and does the maintainer publish it separately?
export HTTPS_PROXY=http://127.0.0.1:PORT HTTP_PROXY=http://127.0.0.1:PORT
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"

echo "########## 1. where is 'so_arm101_description' referenced? ##########"
grep -rn "so_arm101_description" "$HOME/ros2_ws/src/" 2>/dev/null | cut -c1-160 | head -12 | sed 's/^/  /'

echo
echo "########## 2. which description packages are installed/built? ##########"
ros2 pkg list 2>/dev/null | grep -iE "desc|so_arm|sts" | sed 's/^/  /'

echo
echo "########## 3. what xacro does control.launch.py feed to robot_state_publisher? ##########"
grep -rn "xacro\|description\|urdf\|robot_description" "$HOME/ros2_ws/src/so_arm_ros2/so_arm_control/launch/control.launch.py" | cut -c1-170 | head -18 | sed 's/^/  /'

echo
echo "########## 4. joint_trajectory_bridge.yaml (mesh / package settings) ##########"
head -35 "$HOME/ros2_ws/src/so_arm_ros2/so_arm_control/config/joint_trajectory_bridge.yaml" | sed 's/^/  /'

echo
echo "########## 5. does adityakamath publish a separate description repo? ##########"
curl -s --max-time 45 "https://api.github.com/users/adityakamath/repos?per_page=100" \
  | grep -o '"name": "[^"]*"' | sed 's/"name": //' | sort | sed 's/^/  /'

echo
echo "########## 6. what mesh paths does the repo's own URDF use? ##########"
grep -rn "package://" "$HOME"/ros2_ws/src/so_arm_ros2/so_arm_description/urdf/so101/so101.urdf.xacro | head -5 | cut -c1-170 | sed 's/^/  /'
