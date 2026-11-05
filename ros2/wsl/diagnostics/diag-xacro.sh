#!/usr/bin/env bash
# Generate the URDF manually -> see if xacro succeeds, what packages it needs, and what
# command interfaces it declares.
export HTTPS_PROXY=http://127.0.0.1:PORT HTTP_PROXY=http://127.0.0.1:PORT
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"

echo "########## 1. maintainer's repos (parsed cleanly) ##########"
python3 - <<'PY'
import json, urllib.request, ssl
try:
    req = urllib.request.Request("https://api.github.com/users/adityakamath/repos?per_page=100",
                                 headers={"User-Agent": "curl"})
    data = json.load(urllib.request.urlopen(req, timeout=45, context=ssl._create_unverified_context()))
    for r in sorted(data, key=lambda x: x["name"]):
        print(f"  {r['name']:<38} {r.get('description') or ''}"[:150])
except Exception as e:
    print("  lookup failed:", e)
PY

echo
echo "########## 2. xacro arg defaults from urdf_config.yaml ##########"
cat "$HOME/ros2_ws/src/so_arm_ros2/so_arm_control/config/urdf_config.yaml" | sed 's/^/  /'

echo
echo "########## 3. generate the URDF by hand (as control.launch.py would) ##########"
PKG=$(ros2 pkg prefix so_arm_description)/share/so_arm_description
XACRO="$PKG/urdf/so101/so101.urdf.xacro"
ls -l "$XACRO" 2>&1 | sed 's/^/  /'
xacro "$XACRO" so_arm_config:=so101 use_mock:=true ros2_control_hardware_type:=real \
  > /tmp/gen.urdf 2> /tmp/gen.err < /dev/null
echo "  xacro exit=$?  bytes=$(wc -c < /tmp/gen.urdf)"
echo "  --- stderr ---"; head -12 /tmp/gen.err | sed 's/^/    /'

echo
echo "########## 4. mesh packages the generated URDF wants ##########"
grep -o 'package://[^/]*' /tmp/gen.urdf | sort -u | sed 's/^/  /'

echo
echo "########## 5. command interfaces in the generated URDF (first joints) ##########"
grep -nE "<command_interface|</ros2_control>|<ros2_control|<joint name=" /tmp/gen.urdf | head -24 | sed 's/^/  /'

echo
echo "########## 6. robot_state_publisher errors in the launch log ##########"
grep -iE "robot_state_publisher|xacro|error|No such file|package" "$HOME/phase0-mock.log" | head -12 | cut -c1-170 | sed 's/^/  /'
