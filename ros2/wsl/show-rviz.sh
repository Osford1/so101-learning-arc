#!/usr/bin/env bash
# show-rviz.sh — bring up the SO-101 model in RViz, guaranteed visible.
#
#   bash show-rviz.sh
#
# Why this exists: under WSLg the RViz window is often created at an absolute X position
# on the *second* monitor (WSLg re-uses the second display's absolute X origin), so on a
# narrow primary panel it is invisible — the process runs, `xwininfo` lists the
# window, and you see nothing. This script launches the normal bringup and then moves the
# window onto the primary display with xdotool.
#
# Everything it launches is upstream code: robot_state_publisher + joint_state_publisher_gui
# (the slider panel) + rviz2 with the shipped config.

set -euo pipefail

ROS_DISTRO=jazzy
WS="$HOME/so101_ws"
# Layout for a 1280x800 primary panel: sliders left, 3-D view right of them.
SLIDER_X=40;  SLIDER_Y=40
RVIZ_X=320;   RVIZ_Y=40;  RVIZ_W=940; RVIZ_H=700

export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
set +u; source "/opt/ros/${ROS_DISTRO}/setup.bash"; set -u
set +u; source "$WS/install/setup.bash"; set -u

command -v xdotool >/dev/null || { echo "installing xdotool..."; sudo apt-get install -y -qq xdotool; }

# Leftover viewer instances from earlier runs steal the window names and litter the screen.
pkill -f "rviz2" 2>/dev/null || true
pkill -f "joint_state_publisher_gui" 2>/dev/null || true
pkill -f "robot_state_pub" 2>/dev/null || true
sleep 2

# Identify windows by NAME, not geometry: the real viewport is "<config path> - RViz",
# while Qt also exposes 1x1 helper windows named "rviz2" / "Qt Selection Owner for rviz2"
# that a size heuristic keeps picking by mistake.
find_win () {   # $1 = glob to match against the window name
  local w name
  for w in $(xdotool search --name "rviz" 2>/dev/null) $(xdotool search --name "Joint State" 2>/dev/null); do
    name="$(xdotool getwindowname "$w" 2>/dev/null || true)"
    case "$name" in
      $1) echo "$w"; return 0 ;;
    esac
  done
  return 1
}

echo "== launching robot_state_publisher + joint sliders + RViz =="
ros2 launch so_arm101_description view_description.launch.py rviz:=true &
LAUNCH=$!
trap 'kill $LAUNCH 2>/dev/null || true' EXIT

echo "== waiting for the RViz window =="
WID=""
for _ in $(seq 1 25); do
  sleep 1
  WID="$(find_win '*- RViz' || true)"
  [ -n "$WID" ] && break
done

if [ -z "$WID" ]; then
  echo "!! no RViz window appeared — check the launch output above"
  exit 1
fi

echo "== viewport $WID '$(xdotool getwindowname "$WID")' -> ${RVIZ_X},${RVIZ_Y} ${RVIZ_W}x${RVIZ_H} =="
xdotool windowmove "$WID" "$RVIZ_X" "$RVIZ_Y"
xdotool windowsize "$WID" "$RVIZ_W" "$RVIZ_H"

SLIDERS="$(find_win 'Joint State Publisher' || true)"
if [ -n "$SLIDERS" ]; then
  echo "== slider panel $SLIDERS '$(xdotool getwindowname "$SLIDERS")' -> ${SLIDER_X},${SLIDER_Y} =="
  xdotool windowmove "$SLIDERS" "$SLIDER_X" "$SLIDER_Y"
fi

echo
echo "RViz is up. Drag the sliders (the small panel) and the arm model follows —"
echo "that is /joint_states driving TF, i.e. the 'ROS 2 core' rung of the arc."
echo "Ctrl-C here to stop everything."
wait $LAUNCH

