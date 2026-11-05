#!/usr/bin/env bash
# P1 proof, take 2: ros2 topic pub does NOT accept --no-daemon (only list/node/echo do).
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

echo "########## BEFORE: shoulder_pan value ##########"
timeout 20 ros2 topic echo /joint_states --no-daemon --once > /tmp/before.txt 2>&1 < /dev/null
grep -A 8 "^name:" /tmp/before.txt | tail -6 | sed 's/^/  /'

echo
echo "########## publishing shoulder_pan -> -0.25 rad on /joint_commands ##########"
timeout 25 ros2 topic pub --once /joint_commands sensor_msgs/msg/JointState \
  "{name: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'], position: [-0.25, 0.0, 0.0, 0.0, 0.0, 0.0]}" \
  > /tmp/pub.txt 2>&1 < /dev/null
echo "  exit=$?"
tail -3 /tmp/pub.txt | sed 's/^/  /'

echo
echo "########## trajectory reaching the controller? ##########"
timeout 20 ros2 topic echo /so_arm_controller/joint_trajectory --no-daemon --once > /tmp/traj.txt 2>&1 < /dev/null
grep -A 8 "joint_names:" /tmp/traj.txt | head -14 | sed 's/^/  /'

echo
echo "########## AFTER 4 s: did the mock arm move? ##########"
sleep 4
timeout 20 ros2 topic echo /joint_states --no-daemon --once > /tmp/after.txt 2>&1 < /dev/null
grep -A 8 "^name:" /tmp/after.txt | tail -6 | sed 's/^/  /'

echo
echo "########## bridge log ##########"
grep -iE "joint_trajectory_bridge" "$HOME/phase0-mock.log" | tail -4 | cut -c1-190 | sed 's/^/  /'

echo
echo "########## controller log (trajectory accepted?) ##########"
grep -iE "so_arm_controller" "$HOME/phase0-mock.log" | tail -5 | cut -c1-190 | sed 's/^/  /'
