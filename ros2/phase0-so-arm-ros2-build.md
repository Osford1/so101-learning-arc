# Phase 0 — Environment (SO-101, ROS 2 Jazzy on WSL2) — **GATE PASSED 2026-09-15**

**Arc:** `my private roadmap notes (not published)` §P0 · **Live phase table:** `PROJECT-CONTEXT.md`
**Stack:** [`adityakamath/so_arm_ros2`](https://github.com/adityakamath/so_arm_ros2) + `sts_hardware_interface`
**Distro:** WSL2 `Ubuntu-24.04` (24.04.4 LTS, user `<your-user>`, NOPASSWD sudo, systemd, WSLg working)
**Supersedes:** `ros2/runbook-feetech-ros2-driver.md` (that describes the Jazzy stack purged on 2026-09-15)

---

## Gate: what Phase 0 required, and the evidence

| Requirement | Evidence (measured 2026-09-15) |
|---|---|
| ROS 2 core alive | `ros2 pkg list` → **354 packages**; `ros2 topic list --no-daemon` → `/parameter_events /rosout` |
| SO-101 stack launches, controllers **active** | `spawner: Configured and activated joint_state_broadcaster` + `so_arm_controller`; states `active` |
| Hardware interfaces reachable | **6 position + 6 velocity** command interfaces, 6 position + 6 velocity state |
| Telemetry flowing | `/joint_states` publishes all 6 joints (mock) |
| Arm enumerates via usbipd | `usbipd attach --wsl Ubuntu-24.04 --busid 2-1` → `/dev/ttyACM0` (arm not plugged in at time of writing) |

`2-1` is this machine's BUSID, and `Ubuntu-24.04` is this machine's distro name — re-derive both:
`usbipd list` for the BUSID and VID:PID, `wsl -l -v` for the distro.

**Not part of Phase 0:** any real motion. That is P2 and needs a working servo bus (see the end).

## What got installed (this machine)

- `ros-jazzy-desktop` (ROS 2 Jazzy, apt via Tsinghua mirror, from the TUNA ros2 repo)
- Upstream CI's full dependency set: `ros2-control`, `ros2-controllers`, `pinocchio`, `joy`, `joy-teleop`,
  `cv-bridge`, `parallel-gripper-controller`, `rclcpp-lifecycle`, `robot-state-publisher`, `tf2-ros`,
  `xacro`, `control-msgs`, `diagnostic-msgs`, `effort-controllers`, `rosbag2-storage-mcap`,
  `mujoco-ros2-control`, `libfcl-dev`, `python3-opencv`, `python3-{pip,yaml,numpy}`
- `python-fcl` + `numpy-stl` via pip (Tsinghua PyPI), **CI's invocation** (see trap 4)
- `~/ros2_ws/src/{so_arm_ros2, sts_hardware_interface}`; `colcon build` → **4 packages finished**
  (`sts_hardware_interface`, `so_arm_description`, `so_arm_control`, `so_arm_bringup`)

Install log inside the distro: `~/phase0-install.log`. Master log of a launch: `~/phase0-mock.log`.

## The procedure that works

```bash
# 0. clean slate — see trap 3, this is not optional
wsl -d Ubuntu-24.04 -u <your-wsl-user> -- bash -lc 'bash ~/phase0-gate.sh'
#    The gate script kills leftovers, launches mock mode, waits for activation,
#    then prints controllers, interfaces, nodes, /joint_states and errors.

# manual equivalent:
source /opt/ros/jazzy/setup.bash && source ~/ros2_ws/install/setup.bash
ros2 launch so_arm_bringup so_arm.launch.py use_mock:=true wrist_camera:=false
```

Controller states and interface lists (the CLI verbs hang here — see trap 1):

```bash
ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers
ros2 service call /controller_manager/list_hardware_interfaces controller_manager_msgs/srv/ListHardwareInterfaces
ros2 topic list --no-daemon
ros2 topic echo /joint_states --no-daemon --once
```

## Traps found on this host (each cost real debugging time)

1. **The ros2 CLI daemon hangs** under WSL2 `networkingMode=mirrored`. `ros2 topic list` and
   `ros2 node list` time out (exit 124) with an XML-RPC traceback. `--no-daemon` works instantly.
   `ros2 control <verb>` **rejects** `--no-daemon` → query the controller_manager with
   `ros2 service call` instead.
2. **`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` must be in `~/.profile`, not only `~/.bashrc`.**
   `~/.bashrc` returns early for non-interactive shells, so scripts (and `bash -lc`) never see it —
   without it, nodes in different shells silently can't see each other.
3. **Leftover processes poison the new stack.** A stale `robot_state_publisher` from a previous
   launch (or a purged stack) publishes its own `/robot_description` on the same DDS domain. The new
   stack then loads *that* description, producing bizarre downstream errors: a collision-checker
   `LookupError: Could not find the resource 'so_arm101_description'`, `'end_effector_link' not found`,
   and — the confusing one — the controller **refusing to activate because a velocity command
   interface "is not available"** even though the URDF declares it. Kill every node process before
   launching. (`ResourceManager has already loaded a urdf … Ignoring attempt to reload` in the log is
   the tell.)
4. **Install python-fcl/numpy-stl the way upstream CI does:** `--break-system-packages --user
   --ignore-installed`. The bundled `bootstrap_external_deps.sh` omits `--user`/`--ignore-installed`,
   so numpy lands in `/usr/local/lib`; the repo's `kinematics.py` only strips `~/.local/lib` from
   `sys.path`, so pinocchio then dies with a **numpy ABI mismatch**.
5. **`colcon build` plainly** — not `--packages-up-to so_arm_bringup`. `sts_hardware_interface` is a
   separate package loaded at runtime as a plugin, and even `use_mock:=true` loads the real plugin
   with servo I/O faked internally. Skip it and nothing works.
6. **The README's `--recursive` submodule line is stale.** There is no `.gitmodules` and no
   `external/` dir; the vendor SDK is vendored in-tree at `include/SCServo_STS/`.
7. **The controllers are `joint_state_broadcaster` + `so_arm_controller`** (one
   `joint_trajectory_controller` covering all 6 joints incl. the gripper, 50 Hz) — not a per-joint set.
8. **No bundled RViz config.** Visualise with `rviz2` and add a RobotModel display on
   `/robot_description`. Launch args: `model:=so101 use_mock:=true serial_port:=/dev/ttyACM0
   wrist_camera:=false ros2_control_hardware_type:=real|mujoco`.

## Going to real hardware (P2, not yet done)

- No udev in WSL2, so `/dev/ttySERVO` can never exist — pass **`serial_port:=/dev/ttyACM0`**.
- The arm must be attached (`usbipd bind --busid 2-1` once, then `usbipd attach --wsl Ubuntu-24.04
  --busid 2-1`, both BUSIDs read off `usbipd list` on your own machine); attach does **not** survive unplug/replug or `wsl --shutdown`.
- **There is no hardware e-stop in this stack.** `/emergency_stop` is a software service (joystick
  button) that stops the interface issuing commands; it can't help if the stack hangs. Your **12 V
  switch is the real e-stop**. First real motion: one joint, small delta, hand on the switch.
- **The blocker is physical, not software:** the servo bus measured ~20% frame validity at 1 Mbaud
  (fragmented frames = byte loss on the wire). The fix is the swap test — gripper servo → a
  known-good servo, then the cable, then the controller board, then the adapter — each judged with
  `tools/bus_health.py` (healthy ≈ 100%). Scripts: `wsl/find-servo.sh`, `tools/bus_health.py`.

## Scripts written for this phase (`ros2/wsl/`)

`install-phase0.sh` (steps 1–6, idempotent) · `phase0-gate.sh` (clean bring-up + gate evidence) ·
`purge-ros2.sh` (remove a ROS stack, keep the distro) · `verify-phase0.sh`, `diag-*.sh`
(the diagnostics that found the traps above).
