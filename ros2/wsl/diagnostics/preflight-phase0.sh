#!/usr/bin/env bash
# Phase 0 pre-flight: what's already in the 24.04 distro + which Jazzy packages actually exist.
export HTTPS_PROXY=http://127.0.0.1:PORT
export HTTP_PROXY=http://127.0.0.1:PORT
OUT="/tmp/ros_pkgs.gz"

echo "=== WSL 24.04: which tools are already there? ==="
wsl -d Ubuntu-24.04 -u "${WSL_USER:-$(whoami)}" -- bash -lc 'for t in git curl wget pip3 python3; do if command -v "$t" >/dev/null 2>&1; then echo "  OK      $t"; else echo "  MISSING $t"; fi; done'

echo
echo "=== ROS 2 apt repo: is the signing key reachable? ==="
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 40 -x http://127.0.0.1:PORT https://raw.githubusercontent.com/ros/rosdistro/master/ros.key)
echo "  ros.key via proxy -> HTTP $code"
code2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 40 https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu/dists/noble/Release)
echo "  TUNA ros2 mirror Release -> HTTP $code2"

echo
echo "=== fetching the Jazzy/noble package index (TUNA first, then upstream) ==="
curl -sSL --max-time 180 -o "$OUT" "https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu/dists/noble/main/binary-amd64/Packages.gz" \
  || curl -sSLk --max-time 180 -o "$OUT" "https://packages.ros.org/ros2/ubuntu/dists/noble/main/binary-amd64/Packages.gz"
ls -lh "$OUT" 2>/dev/null | awk '{print "  index size:", $5}'

echo "=== do these packages exist for jazzy/noble? ==="
gzip -dc "$OUT" 2>/dev/null | grep -E "^Package: ros-jazzy-(ros-base|desktop|ros2-control|ros2-controllers|pinocchio|joy|joy-teleop|cv-bridge|rosbag2-storage-mcap|mujoco-ros2-control|joint-state-broadcaster|joint-trajectory-controller|xacro|robot-state-publisher|rviz2)$" | sort -u | sed 's/Package: /  FOUND /'
