#!/usr/bin/env bash
# Generate the URDF and inspect exactly what it declares. (Sections cut off last run.)
source /opt/ros/jazzy/setup.bash
source "$HOME/ros2_ws/install/setup.bash"

PKG=$(ros2 pkg prefix so_arm_description)/share/so_arm_description
XACRO="$PKG/urdf/so101/so101.urdf.xacro"
echo "########## xacro path ##########"
ls -l "$XACRO" 2>&1 | sed 's/^/  /'

echo
echo "########## generating ##########"
xacro "$XACRO" so_arm_config:=so101 use_mock:=true ros2_control_hardware_type:=real \
      serial_port:=/dev/ttyACM0 arm_operating_mode:=0 gripper_operating_mode:=0 \
      > /tmp/gen.urdf 2> /tmp/gen.err < /dev/null
echo "  exit=$?  bytes=$(wc -c < /tmp/gen.urdf)"
echo "  --- stderr (first 15) ---"; head -15 /tmp/gen.err | sed 's/^/    /'

echo
echo "########## mesh packages referenced ##########"
grep -o 'package://[^/]*' /tmp/gen.urdf | sort -u | sed 's/^/  /'

echo
echo "########## the ros2_control block for the FIRST joint ##########"
awk '/<ros2_control/{f=1} f{print} /<\/ros2_control>/{if(f){exit}}' /tmp/gen.urdf | head -45 | sed 's/^/  /'

echo
echo "########## does the URDF declare velocity command interfaces at all? ##########"
echo "  position count: $(grep -c '<command_interface name="position"/>' /tmp/gen.urdf)"
echo "  velocity count: $(grep -c '<command_interface name="velocity"/>' /tmp/gen.urdf)"
echo "  effort   count: $(grep -c '<command_interface name="effort"/>' /tmp/gen.urdf)"
echo "  hardware plugin line:"; grep -n "<plugin>" /tmp/gen.urdf | head -3 | sed 's/^/    /'
echo "  mock param lines:"; grep -n "mock" /tmp/gen.urdf | head -5 | sed 's/^/    /'
