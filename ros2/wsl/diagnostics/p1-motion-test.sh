#!/usr/bin/env bash
# Does the mock arm follow a commanded trajectory? Sample the state over time.
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

sample() {
  timeout 15 ros2 topic echo /joint_states --no-daemon --once > /tmp/s.txt 2>&1 < /dev/null
  python3 - <<'PY'
import re
t = open('/tmp/s.txt', errors='ignore').read()
names = re.findall(r"^- (\w+)$", t.split('position:')[0], re.M)
pos = re.findall(r"^- (-?[\d.eE+-]+)$", t.split('position:')[-1], re.M)
d = dict(zip(names, [float(p) for p in pos[:len(names)]]))
print("    ", {k: round(v, 4) for k, v in d.items()})
PY
}

echo "########## BEFORE ##########"
sample

echo
echo "########## sending a 3-second trajectory to shoulder_pan = -0.30 (direct to the controller) ##########"
timeout 25 ros2 topic pub --once /so_arm_controller/joint_trajectory \
  trajectory_msgs/msg/JointTrajectory \
  "{joint_names: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'],
    points: [{positions: [-0.30, 0.0, 0.0, 0.0, 0.0, 0.0], velocities: [0.0,0.0,0.0,0.0,0.0,0.0], time_from_start: {sec: 3, nanosec: 0}}]}" \
  > /dev/null 2>&1 < /dev/null
echo "  published (exit=$?)"

echo "  after 1.5 s:"; sleep 1.5; sample
echo "  after 3.5 s:"; sleep 2;   sample
echo "  after 6 s:";   sleep 2.5; sample

echo
echo "########## same test through the bridge's own input topic ##########"
timeout 25 ros2 topic pub --once /joint_commands sensor_msgs/msg/JointState \
  "{name: ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint','wrist_flex_joint','wrist_roll_joint','gripper_joint'], position: [0.35, 0.0, 0.0, 0.0, 0.0, 0.0]}" \
  > /dev/null 2>&1 < /dev/null
echo "  after 3 s:"; sleep 3; sample

echo
echo "########## controller manager activity (any aborted goals?) ##########"
grep -iE "aborted|rejected|invalid|tolerance" "$HOME/phase0-mock.log" | tail -5 | cut -c1-170 | sed 's/^/  /' || echo "  (nothing)"
