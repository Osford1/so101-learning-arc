# SO-101 explicit control over ROS 2 (WSL2) — bring-up runbook

> **PURGED 2026-09-15 — historical reference only.** The stack this describes (`/opt/ros/jazzy`,
> `~/so101_ws`, and the LeRobot env) was deliberately removed to restart from
> [`adityakamath/so_arm_ros2`](https://github.com/adityakamath/so_arm_ros2) — ROS 2 **Jazzy**, with
> `sts_hardware_interface` built as its own package in the workspace. The distro below is kept.
> Still valid and worth reading: the WSL2 + usbipd mechanics, the `ROS_AUTOMATIC_DISCOVERY_RANGE`
> DDS trap, the zero-position convention, and the servo-bus diagnosis in `tools/`.

**What this is:** the "you write the controller" rung of the SO-101 learning arc
(Phase 0–2): ROS 2 Jazzy + `ros2_control` talking to the follower's
Feetech STS3215 servos directly, so a trajectory *I* generate is what the arm
executes. No teleop operator, no learned policy in the loop.

**Where it lives:** a dedicated WSL2 distro `Ubuntu-24.04` (its virtual disk on a secondary drive),
ROS 2 workspace `~/so101_ws` (both purged on 2026-09-15; the distro remains). The `Ubuntu` 22.04
distro held the LeRobot / HIL-SERL conda env — also removed on 2026-09-15.

```
Windows host                              WSL2 distro: Ubuntu-24.04
┌──────────────────────────┐              ┌──────────────────────────────────────┐
│ SO-101 follower (12 V)   │              │ /dev/ttyACM0                         │
│   └─ USB-C → CH34x       │              │        ▲                             │
│        adapter           │              │        │ serial (STS3215 bus)        │
│          │               │  usbipd      │  feetech_ros2_driver                 │
│          ▼               ├─────────────▶│        ▲                             │
│   usbipd-win 5.3         │  attach      │  ros2_control (controller_manager)   │
│   (attach-arm.ps1)       │              │        ▲                             │
└──────────────────────────┘              │  joint_trajectory_controller ──► your│
                                          │  forward_position_controller    node │
                                          │  joint_state_broadcaster → /joint_states│
                                          └──────────────────────────────────────┘
```

## Why this shape (decision record)

| Decision | Reason |
|---|---|
| **Ubuntu 24.04, not the existing 22.04** | `ros2_so_arm` (description + MoveIt config) is CI-tested on **jazzy/kilted/rolling only**; `so101_ros2` is Jazzy-only. ROS 2 Jazzy debs exist for **noble** only, so Jazzy needs 24.04. Humble *would* run on 22.04 and the Feetech driver is CI-tested there, but then the description/MoveIt packages and the rest of the SO-101 stack are off the table. |
| **A second distro instead of upgrading 22.04** | `do-release-upgrade` would put the verified LeRobot 0.6.2 / HIL-SERL conda env at risk for no gain. The distro is 1.5 GB and disposable; the env is not. |
| **Only one distro owns the arm at a time** | usbipd attaches a USB device to *one* distro. Calibrating with LeRobot (22.04) and commanding with ROS (24.04) means re-attaching — see "Switching who owns the arm". |
| **`joint_config_file` YAML instead of URDF `<param>`** | The current driver **ignores** the URDF `offset` param (it always centres on tick 2048) and takes per-servo settings from a YAML file. Upstream `so_arm101.ros2_control.xacro` still uses the old param, so I ship my own hardware block (`so101_local`). |
| **ROS 2 in a VM at all** | Yes, it works: WSL2 gives a real Linux kernel, `/dev/ttyACM*` via usbip, WSLg for RViz. It is *not* the same as native Ubuntu: USB/IP adds a hop to every serial packet, so a 50 Hz control loop is fine but latency spikes are possible. If tracking ever gets flaky, native Ubuntu/dual-boot is the fallback. |

## Verified on this box (2026-09-14)

Measured, not assumed — each line is a command that was run and its real result:

| Gate | Evidence |
|---|---|
| ROS 2 Jazzy + ros2_control installed in a fresh Ubuntu 24.04 WSL distro | `ros2 pkg list` → 27 MoveIt packages, `gripper_controllers`, `parallel_gripper_controller`, `ros2_control` stack all present |
| Workspace builds | `colcon build` → **7 packages finished** (feetech driver compiled clean in 43 s, with upstream's `-Werror`) |
| Control loop runs with no hardware | `run-mock.sh --verify` → `joint_state_broadcaster` + `joint_trajectory_controller` **active**, 6 command interfaces **claimed**, trajectory goal → `Goal finished with status: SUCCEEDED`, `/joint_states` follows |
| The one-joint tool works | `jog_one_joint.py --joint wrist_roll_joint --delta 0.10` → moved `+0.0990 rad`, every other joint stayed exactly put; second jog on `shoulder_pan_joint` `-0.1485 rad` with `wrist_roll` still holding |
| Real-hardware path resolves (minus the arm) | `hardware_type:=real usb_port:=/dev/ttyACM0` → `Loaded hardware 'SO_ARM101' from plugin 'feetech_ros2_driver/FeetechHardwareInterface'`, then `Open [/dev/ttyACM0]: Bad file descriptor` — i.e. everything loads up to the missing device |
| usbipd-win | 5.3.0 installed; `usbipd list` works unprivileged |
| RViz over WSLg | `view_description.launch.py rviz:=true` → `rviz2` reports **OpenGl version: 4.5 (GLSL 4.5)**, 3 processes up. NB the launch defaults `rviz:=false`, so you must pass the flag — no flag and you get only the joint-slider panel |

**Not yet verified (needs the arm plugged in):** actual serial traffic, real joint motion and the
direction/zero conventions. (Gazebo also untested — `ros-gz` is installed.)

## Files

```
so101-learning-arc/ros2/
├── README.md                     ← this runbook
├── windows/
│   ├── install-usbipd.ps1        ← one-time, elevates (UAC): installs usbipd-win
│   └── attach-arm.ps1            ← plug in the arm, then run this: bind + attach to the ROS distro
├── wsl/
│   ├── 00-install-ros-jazzy.sh   ← one-time: ROS 2 Jazzy + ros2_control (TUNA mirrors)
│   ├── 01-build-workspace.sh     ← clone upstream + build ~/so101_ws
│   ├── make-joint-config.sh      ← LeRobot calibration JSON → driver joint config (no rebuild needed)
│   ├── run-mock.sh               ← control loop with NO hardware
│   ├── run-real-follower.sh      ← the real arm (supervised, asks for confirmation)
│   ├── show-rviz.sh              ← viewer, force-placed on the primary display (WSLg puts it on the 2nd)
│   └── test-one-joint.sh         ← FIRST real motion: one joint, 0.1 rad
├── ws_src/so101_local/           ← my overlay package (controller + joint config + hardware xacro)
├── calib/                        ← drop the follower's LeRobot calibration JSON here
└── tools/
    ├── lerobot_calib_to_ros_joints.py  ← LeRobot calibration JSON → driver joint_config_file
    ├── read_servo_ticks.py             ← raw ticks / where "zero" is (read-only)
    ├── scan_servo_bus.py               ← LeRobot wide id × baud scan with a verdict
    ├── servo_bus_ping.py               ← pyserial-only raw ping; --watch / --dump-id / --repeat; runs on Windows COM ports too
    ├── joint_state_snapshot.py         ← readable joint_states + a "what moved" diff
    └── jog_one_joint.py                ← one-joint move via the trajectory controller
```

## Install (once)

```bash
# Windows, admin-free wrapper that elevates itself for the MSI:
powershell -ExecutionPolicy Bypass -File so101-learning-arc/ros2/windows/install-usbipd.ps1

# inside the Ubuntu-24.04 distro:
wsl -d Ubuntu-24.04
bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/00-install-ros-jazzy.sh
bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/01-build-workspace.sh
```

`00-…` points apt at TUNA (Ubuntu archive + `ros2/ubuntu`) and adds a rosdep
rosdistro mirror, because a restricted network makes `packages.ros.org` and the rosdistro
GitHub raw fetches unreliable.

## Bring-up with the arm (every session)

```powershell
# 1. Windows: follower on 12 V PSU + USB-C in, then
powershell -ExecutionPolicy Bypass -File so101-learning-arc/ros2/windows/attach-arm.ps1
#    (first time per device: 'usbipd bind --busid <BUSID>' in an ADMIN PowerShell, once)
```

```bash
# 2. WSL
wsl -d Ubuntu-24.04
bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/run-real-follower.sh /dev/ttyACM0
# 3. in a second WSL shell — the first motion:
bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/test-one-joint.sh wrist_roll_joint
```

Safety rules baked into the scripts: `run-real-follower.sh` refuses to start if the
joint config still holds `REPLACE_ME`, and asks for a typed `YES` before handing the
servos to `ros2_control`. `test-one-joint.sh` moves **one** joint by 0.1 rad and holds
the others where they are — an inverted sign or a wrong zero shows up as a small
wrong motion instead of a full-arm throw.

## The one non-obvious thing: where "zero" is

Two stacks, same servos, two conventions — worth understanding before the first run,
because a mismatch is the difference between "the arm twitches 5°" and "the arm
slams into its limit".

- **LeRobot** reports joint angles in **degrees**, centred on the **midpoint of the
  recorded travel range**: `0° = (range_min + range_max)/2` ticks. During
  `lerobot-calibrate` it also writes a `Homing_Offset` into each servo's **EEPROM** so
  that the mid pose reads tick 2048.
- **The ROS driver** reads raw ticks and treats tick **2048 as joint angle 0**, taking
  `range_min`/`range_max` (in ticks) from the `joint_config_file`.

Those agree when the calibration midpoint is ~2048 — which is the normal outcome
(`read_servo_ticks.py` and the converter both check and print this). Then:

- the tick limits transfer 1:1 → they become the driver's `range_min`/`range_max`, so
  the servos refuse to drive past what LeRobot already proved is safe;
- and the converter deliberately **does not** emit `homing_offset`, because that
  parameter is written to EEPROM and LeRobot has already put its own value there.
  Writing a second one silently invalidates the calibration file.
- if a joint's midpoint is far from 2048, the two zeros differ by that many ticks —
  the converter reports the degrees of disagreement instead of hiding it.

Two things it cannot decide for you, because they are convention, not calibration:
**(a)** whether the LeRobot zero pose is the pose the URDF calls zero, and
**(b)** joint **signs** (`drive_mode=1` in the calibration means LeRobot negates that
joint; the ROS driver has no equivalent flag). Both show up on the first
`test-one-joint.sh` run: wrong-sign → the joint goes the other way; wrong zero → the
whole arm starts from a shifted pose. Fix a sign in the URDF axis, a zero by choosing
`--ticks-at-zero` (EEPROM write → re-run `lerobot-calibrate` afterwards), never by
"only adding steps".

## Switching who owns the arm

```powershell
usbipd detach --busid <BUSID>                             # release from the ROS distro
usbipd attach --wsl Ubuntu --busid <BUSID>                # give it to the LeRobot distro
```

The distro is the **value** of `--wsl` (`--wsl Ubuntu`), not `--wsl --distribution Ubuntu`.
An attach lasts only until the device is unplugged, `wsl --shutdown` runs, or you detach it —
after any of those, re-run it.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ls /dev/ttyACM*` empty in WSL | usbipd hasn't attached it, or attached it to the *other* distro (`usbipd list` shows the STATE column: `Attached` / `Not shared`). |
| `lerobot-find-port` → `Could not detect the port. No difference was found ([])` | By design it lists `/dev/tty*` **before and after** you unplug the USB cable and looks for the difference (`lerobot_find_port.py:45-64`). That workflow cannot work under usbipd: if the arm isn't attached, nothing changes (0 diff → this exact error); and if it *is* attached, unplugging the USB **detaches** it from WSL and replugging never re-attaches it, so the port it waits for can't reappear. **Never use `lerobot-find-port` here — always pass `--robot.port=/dev/ttyACM0` explicitly.** |
| `chmod: cannot access '/dev/ttyACM0': No such file or directory` | The node isn't there **at all**, and `chmod` on a missing node can't fix that — the USB/IP attach is gone. It does not survive an unplug/replug, a `wsl --shutdown`, or a `usbipd detach` (so a detach-then-forget leaves exactly this error; it is *not* a Linux permissions problem). Check `usbipd list` and re-run `attach-arm.ps1`, then `ls /dev/ttyACM*` before chmod. |
| `lerobot-setup-motors` → `Motor 'gripper' (model 'sts3215') was not found` while a servo is plainly answering | Its probe (`_find_single_motor_p0`) requires a **model number in the PING reply**. These servos answer a 6-byte frame `ff ff 01 02 00 fc` with no model bytes, so the tool rejects a live servo. Configure IDs with `tools/servo_regs.py` (`probe`, `set-id`) instead, and use `tools/bus_health.py` to prove the link first. |
| Servo answers *sometimes*, and reads/ID-writes silently fail | Never guess — measure with `python3 tools/bus_health.py --port /dev/ttyACM0`: it reports **frame validity** (a healthy STS3215 bus is ~100% at 1 Mbaud) plus the failure shapes. Measured on this arm: **20% @ 1 Mbaud, 76% @ 250k, 70% @ 115200** — a bandwidth-limited *physical* layer (cable / servo / board), not a config problem. Swap one part at a time and re-measure; no software change turns 20% into 100%. |
| `usbipd attach` → "device is not shared" | One-time `usbipd bind --busid X` in an **admin** PowerShell (per device, persists). |
| Controller won't come up: `Could not find the plugin feetech_ros2_driver/FeetechHardwareInterface` | Workspace not sourced: `source ~/so101_ws/install/setup.bash`. |
| Serial timeouts / `sync_read` errors under load | USB/IP + one CH34x adapter running 6 servos at 50 Hz: lower `update_rate` in the controller YAML, or move to native Ubuntu. |
| `/dev/so101_follower` symlink missing | Expected in WSL2 — the upstream udev names don't exist here; always pass `usb_port:=/dev/ttyACM…` explicitly. |
| Arm moves the wrong way on one joint | Sign convention (`drive_mode`), see above — not a wiring fault. |
| `ros2 topic list` shows only `/parameter_events` + `/rosout`, controller_manager sits at "Waiting for data on 'robot_description'", spawners can't find `/controller_manager/*` | **DDS multicast doesn't survive WSL2 mirrored networking** (mirrored mode is what makes the local HTTP proxy reachable, so it stays). Fix: `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` — everything here is on one machine, so unicast on `lo` is enough. This is exported by `00-install-ros-jazzy.sh` into `~/.bashrc` and by every script in `wsl/`. |
| `ros2` CLI commands hang, though the nodes are clearly alive | A `ros2` daemon started while discovery was broken stays poisoned. `ros2 daemon stop` then retry. |
| Spawner says `Failed to activate controller : forward_position_controller` | Two controllers cannot claim the same command interface. `joint_trajectory_controller` already holds the five arm joints — **switch**, don't stack: `ros2 control switch_controllers --deactivate joint_trajectory_controller --activate forward_position_controller`. |
| Launching `hardware_type:=real` with no arm attached kills `ros2_control_node` (exit code -6) | The Feetech driver throws `LibSerial::NotOpen` instead of failing gracefully when it can't open `usb_port`. Attach the arm *before* launching; this exit code is "no device", not a driver bug. |
| RViz runs but **no window is visible** | WSLg places the window at an absolute X on the second display (seen here: far to the right of the primary panel). The process is alive and `xwininfo -root -tree \| grep RViz` lists it. Fix: `xdotool search --name RViz \| tail -1 \| xargs -I{} xdotool windowmove {} 40 40` (then `windowsize`), or use `wsl/show-rviz.sh`. Check `xwininfo` before assuming RViz failed to start. |
| `view_description.launch.py` shows a slider panel but no 3-D view | That launch defaults **`rviz:=false`**. Pass `rviz:=true`. |
| RViz opens but the scene is empty | Nothing is publishing `/robot_description` or TF — start `robot_state_publisher` too (the launch does both; a bare `rviz2` does not). |
| Comment says the arm should hold its pose but it goes slack | The driver disables torque on shutdown/disconnect by design (`disable_torque_on_disconnect` in LeRobot, servo-level `Torque_Enable=0` here). Support the arm when killing the bring-up. |

## Parked (deliberately not done yet — staged delivery)

- **Gazebo / MuJoCo sim** (Phase 0 gate's "sim launches", Phase 3 pick-and-place in sim).
  Upstream `hardware_type:=gazebo|mujoco` exists; `ros-gz` was installed so it is a launch away.
- **MoveIt 2** (`so_arm101_moveit_config demo.launch.py`, `hardware_type:=mock_components` /
  `:=real`) — installed, first target after one-joint motion works.
- **The LeRobot bridge** (`legalaspro/so101-ros-physical-ai`: leader↔follower teleop,
  episode recorder, rosbag → LeRobot dataset, policy inference) — Jazzy, and the natural
  Phase 5+ home. It wants the Feetch driver + a udev symlink I override; worth doing once
  the compact stack is proven.
- **LeRobot in the 24.04 distro** — would put ROS 2, LeRobot and the bridge in one place
  instead of shuttling the USB attachment between two distros.
