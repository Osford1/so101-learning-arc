#!/usr/bin/env bash
# 00-install-ros-jazzy.sh — install ROS 2 Jazzy + ros2_control on a fresh Ubuntu 24.04 (WSL2)
#
# Verified on: Ubuntu 24.04 LTS (noble) inside WSL2, behind a local HTTP proxy (a restricted outbound network -
# substitute your own proxy port; networkingMode=mirrored). Uses TUNA mirrors so the big downloads actually finish.
#
#   bash 00-install-ros-jazzy.sh
#
# Idempotent: safe to re-run.

set -euo pipefail

ROS_DISTRO=jazzy
KEYRING=/usr/share/keyrings/ros-archive-keyring.gpg
TUNA_UBUNTU=https://mirrors.tuna.tsinghua.edu.cn/ubuntu
TUNA_ROS2=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu

echo "== 0. sanity: Ubuntu $(lsb_release -rs) $(lsb_release -cs) =="
CODENAME=$(lsb_release -cs)
if [ "$CODENAME" != "noble" ]; then
  echo "!! ROS 2 Jazzy targets Ubuntu 24.04 (noble); this is $CODENAME. Aborting." >&2
  exit 1
fi

echo "== 1. point apt at TUNA (Ubuntu archive + security) =="
# 24.04 uses deb822 sources
for f in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list; do
  [ -f "$f" ] && sudo sed -i \
    -e "s|http://archive.ubuntu.com/ubuntu|$TUNA_UBUNTU|g" \
    -e "s|http://security.ubuntu.com/ubuntu|$TUNA_UBUNTU|g" \
    -e "s|https://archive.ubuntu.com/ubuntu|$TUNA_UBUNTU|g" \
    -e "s|https://security.ubuntu.com/ubuntu|$TUNA_UBUNTU|g" "$f"
done
sudo apt-get update -qq

echo "== 2. base tooling =="
sudo apt-get install -y -qq curl gnupg lsb-release software-properties-common ca-certificates git cmake build-essential python3-pip
sudo add-apt-repository -y universe >/dev/null

echo "== 3. ROS 2 apt key + TUNA ros2 repo =="
sudo mkdir -p /usr/share/keyrings
if [ ! -s "$KEYRING" ]; then
  curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    | sudo gpg --dearmor -o "$KEYRING"
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRING] $TUNA_ROS2 $CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null
sudo apt-get update -qq

echo "== 4. ROS 2 $ROS_DISTRO desktop + ros2_control stack =="
sudo apt-get install -y -qq \
  ros-${ROS_DISTRO}-desktop \
  ros-${ROS_DISTRO}-ros2-control \
  ros-${ROS_DISTRO}-ros2-controllers \
  ros-${ROS_DISTRO}-ros2controlcli \
  ros-${ROS_DISTRO}-controller-manager \
  ros-${ROS_DISTRO}-xacro \
  ros-${ROS_DISTRO}-joint-state-publisher \
  ros-${ROS_DISTRO}-joint-state-publisher-gui \
  ros-${ROS_DISTRO}-nav2-common \
  ros-${ROS_DISTRO}-rqt-joint-trajectory-controller \
  python3-colcon-common-extensions \
  python3-rosdep

# nice-to-have; never let a missing name fail the whole install
sudo apt-get install -y -qq \
  ros-${ROS_DISTRO}-plotjuggler-ros \
  ros-${ROS_DISTRO}-moveit \
  ros-${ROS_DISTRO}-ros-gz \
  || echo "   (some optional packages were unavailable — continuing)"

echo "== 5. rosdep (TUNA rosdistro mirror so it works behind a restricted network) =="
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
  sudo rosdep init || true
fi
rosdep update --rosdistro "$ROS_DISTRO" || {
  echo "   retrying rosdep update with the TUNA rosdistro index"
  export ROSDISTRO_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/rosdistro/index-v4.yaml
  rosdep update --rosdistro "$ROS_DISTRO"
}

echo "== 6. source ROS in every new shell =="
if ! grep -q "ros/${ROS_DISTRO}/setup.bash" "$HOME/.bashrc"; then
  {
    echo ""
    echo "# ROS 2 ${ROS_DISTRO}"
    echo "# WSL2 'mirrored' networking (required here for the local proxy) does NOT carry"
    echo "# multicast into the distro, so default DDS discovery finds nothing: nodes never"
    echo "# see each other and ros2 topic list shows only /parameter_events + /rosout."
    echo "# LOCALHOST discovery (unicast on lo) is the fix — everything here is on one machine."
    echo "export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST"
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash"
    echo "[ -f \$HOME/so101_ws/install/setup.bash ] && source \$HOME/so101_ws/install/setup.bash"
  } >> "$HOME/.bashrc"
fi

echo
echo "DONE. Verify with a NEW shell:"
echo "  source /opt/ros/${ROS_DISTRO}/setup.bash"
echo "  ros2 --version && ros2 pkg list | grep -c ros2_control"
echo "  ros2 control --help"
