# Session log — 2026-09-14 · SO-101 explicit control on ROS 2 (WSL2) — Phase 0/1/2 bring-up

> **Class: verified result.** Appended live during the session; commands and outputs are as
> they were run.

**Project:** SO-101 learning arc (§ PROJECT-CONTEXT.md) · **Phase:** 0 (environment) → 2 (ros2_control)
**Date:** Monday, 2026-09-14 (CST) · **Location:** Windows laptop (WSL2), **arm not attached**
**Ask (user):** "I have my SO-101 arm, I want to use explicit control on the follower arm.
Is it possible on a virtual machine? If so set it up so I can plug the robot in and use it."
**Runbook produced:** `ros2/runbook-feetech-ros2-driver.md`

> LIVE log — append as events happen. This file is the source for the session report.

---

## 0. Worksheet

| Field | Value |
|---|---|
| Robot | LeRobot SO-101 follower (12 V), 6× STS3215; leader not needed for explicit control |
| Host / OS | Windows, WSL2 (**new distro** `Ubuntu-24.04`, vhdx on a secondary drive) |
| ROS | ROS 2 **Jazzy**, `ros2_control` 4.x, controller_manager @ 50 Hz |
| Workspace | `~/so101_ws` (7 packages: `feetech_ros2_driver`, `so_arm101_description`, `so_arm101_local` overlay, `so_arm*_moveit_config`, `so_arm_gz`) |
| Bridge | usbipd-win **5.3.0** (`C:\Program Files\usbipd-win`) |
| Arm port (target) | `/dev/ttyACM0` in the 24.04 distro, after `usbipd attach` |
| Gate claimed today | "ROS 2 Jazzy in WSL2 + ros2_control moves joints" — **mock hardware only**; real motion still untested |

---

## 1. Decision record (why these choices)

| Decision | Reason |
|---|---|
| Ubuntu **24.04**, not the existing 22.04 distro | ROS 2 **Jazzy** debs are noble-only, and `ros2_so_arm` is CI-tested on jazzy/kilted/rolling **only** (no humble). Its Feetech driver *is* humble-tested, but the description/MoveIt packages are not — so Humble on 22.04 would have halved the stack. |
| **Second distro** instead of `do-release-upgrade` | Upgrading would have put the verified LeRobot 0.6.2 / HIL-SERL conda env (22.04) at risk to save nothing. |
| vhdx on **D:** | C: is 86 % full (65 GB free); D: is empty. |
| `joint_config_file` YAML, not URDF `<param>` | Current driver **ignores** the URDF `offset` param (always centres on tick 2048) and reads per-servo settings from YAML. Upstream xacro still uses the old param → I ship my own hardware block in `so101_local`. |
| ROS 2 **in a VM at all** | Yes: real kernel, `/dev/ttyACM*` via usbip, WSLg for RViz. Caveat recorded: USB/IP adds a hop per serial packet — fine at 50 Hz, but native Ubuntu is the fallback if tracking gets flaky. |

---

## 2. What was actually done (path + results)

```
[17:2x]  winget install dorssel.usbipd-win (unelevated) → "You cancelled the installation", exit 1602
         → retried via install-usbipd.ps1 (Start-Process -Verb RunAs) → usbipd-win 5.3.0 installed
[17:21]  wsl --install Ubuntu-24.04 --name Ubuntu-24.04 --location '<your-vhdx-path>' --no-launch --version 2
         → "Distribution successfully installed"  (image download ≈1.5 GB, ~10 min)
[17:31]  WSL user created (groups sudo,adm,dialout,plugdev; NOPASSWD sudo), /etc/wsl.conf → default=<user>
         → id <user> = uid 1000 groups 4,20,27,46
[17:31]  bash 00-install-ros-jazzy.sh   (apt → TUNA: ubuntu + ros2/ubuntu; rosdep via GitHub raw)
         → SCRIPT_EXIT=0  (~15 min; ros-jazzy-desktop + ros2-control + controllers + ros2controlcli
            + nav2-common + rqt-jtc + colcon + rosdep; optional: moveit, ros-gz, plotjuggler)
[17:47]  bash 01-build-workspace.sh
         FAIL 1: ros-jazzy setup.bash aborts under `set -u` → "AMENT_TRACE_SETUP_FILES: unbound variable"
         FAIL 2: my python edit rewrote the .sh files with CRLF → "$\r: command not found"
         FAIL 3: so101_local package.xml "<maintainer email=<user>@localhost>" → catkin_pkg InvalidPackage
         ok after fixes: "Summary: 7 packages finished [57.7s]" (feetech driver 42.9 s, upstream -Werror clean)
[17:44]  run-mock.sh → bring-up hung: controller_manager "Waiting for data on 'robot_description'" forever,
         spawners "Could not contact service /controller_manager/list_controllers", `ros2 topic list` empty,
         `ros2 daemon start` unresponsive.
         → DDS DIAGNOSIS (see §3): default SUBNET discovery is dead in this network mode.
[17:57]  run-mock.sh --verify → PASS
         joint_state_broadcaster + joint_trajectory_controller ACTIVE; 6 command interfaces claimed;
         FollowJointTrajectory goal → "Goal successfully reached!", status SUCCEEDED; /joint_states follows.
[18:0x]  jog_one_joint.py v1 (streaming to forward_position_controller) → spawner "Failed to activate
         controller" (trajectory controller already owns those interfaces) → tool rewritten to drive the
         trajectory controller. Re-verified: wrist_roll +0.0990 rad, shoulder_pan −0.1485 rad, others held.
[19:56]  real-hardware path check (no arm): `hardware_type:=real usb_port:=/dev/ttyACM0` →
         "Loaded hardware 'SO_ARM101' from plugin 'feetech_ros2_driver/FeetechHardwareInterface'"
         then "init_transport_ -> Open [/dev/ttyACM0]: Bad file descriptor" → LibSerial::NotOpen →
         terminate (exit code -6). Everything resolves except the device. Joint-config template restored (12× REPLACE_ME).
```

Wall-clock: ~17:20 → 19:57 (≈2 h 40 m), the bulk of it the two downloads (distro image, ROS debs).

---

## 3. The finding worth keeping: WSL2 mirrored networking kills DDS discovery

Symptom → nodes and CLI could not see each other *inside one distro*.

Matrix actually measured (`demo_nodes_cpp talker` + `ros2 topic list --no-daemon`):

| Configuration | Result |
|---|---|
| default (`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, FastDDS) | **FAIL** — only `/parameter_events`, `/rosout`; `/chatter` never appears |
| `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` | **PASS** — `/chatter` found, `data: 'Hello World: 17'` received |
| FastDDS profile, UDPv4 `interfaceWhiteList=127.0.0.1` | **PASS** (works, but needs an XML file) |
| CycloneDDS pinned to `lo` | **FAIL** — `lo: does not match an available interface` |

Cause: `.wslconfig` uses `networkingMode=mirrored` (needed so the local proxy reaches the
blocked hosts), and mirrored mode does not carry multicast into the distro; the default
SUBNET discovery then multicasts onto the campus LAN (`eth0 <campus LAN address>/21`) and finds nobody.

**Fix adopted:** `export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` — written into the distro's
`~/.bashrc` by `00-install-ros-jazzy.sh` **and** exported by every script in `ros2/wsl/`.
(Same class of problem will hit anyone running ROS 2 in this WSL setup, hence it is also in `ros2/runbook-feetech-ros2-driver.md`.)

---

## 4. Deliverables (all under `ros2\`)

| File | What it is |
|---|---|
| `runbook-feetech-ros2-driver.md` | the runbook: architecture, decision record, verified-gates table, bring-up, calibration/zero mapping, troubleshooting, parked work |
| `windows/install-usbipd.ps1` | one-time, self-elevating usbipd-win install (verified) |
| `windows/attach-arm.ps1` | plug in arm → bind + attach the CH34x adapter to `Ubuntu-24.04` |
| `wsl/00-install-ros-jazzy.sh` | ROS 2 Jazzy + ros2_control via TUNA mirrors + the discovery fix |
| `wsl/01-build-workspace.sh` | clone upstream + overlay, rosdep, colcon build (~/so101_ws) |
| `wsl/run-mock.sh` | control loop, no hardware (`--verify` = the gate) |
| `wsl/run-real-follower.sh` | real arm, refuses to run on an unfilled joint config, asks for typed YES |
| `wsl/test-one-joint.sh` | first real motion: one joint, 0.1 rad |
| `ws_src/so101_local/` | overlay package: controller set, joint config, real-hardware xacro |
| `tools/lerobot_calib_to_ros_joints.py` | LeRobot calibration JSON → driver `joint_config_file` (tested on synthetic data) |
| `tools/read_servo_ticks.py` | read-only: raw ticks / where "zero" is on each servo |
| `tools/jog_one_joint.py` | one-joint move via the trajectory controller (verified on mock) |

---

## 5. Open questions / NEXT SESSION TARGET

Ordered by what becomes unrecoverable first:

1. **Where is the follower's LeRobot calibration JSON?**
   `~/.cache/huggingface/lerobot/calibration/robots/so101_follower/<arm_id>.json` **on the lab Ubuntu box**
   (it does not exist on this laptop — checked). Needed to generate the real `joint_config_file`.
   Copy it over before anything else; without it the real bring-up is blocked by design.
2. **One-time admin step:** `usbipd bind --busid <BUSID>` with the arm plugged in (then `attach-arm.ps1`).
3. **Zero-pose check:** arm hand-jogged to the URDF zero pose → `read_servo_ticks.py` → are ticks ≈ 2048?
   If not, the two zeros differ by the printed amount (decide between `--ticks-at-zero` on the ROS side —
   an EEPROM write that invalidates LeRobot's calibration — or a URDF fix).
4. **Sign check:** `test-one-joint.sh wrist_roll_joint` → does the joint move the way it was told, and do
   the other five stay put?
5. **Then:** `ros2 control list_hardware_interfaces` claimed + a 5-joint trajectory at low speed while watching
   for `sync_read` timeouts (the USB/IP latency risk).

**Parked (staged delivery — do not start unprompted):** RViz via WSLg, Gazebo (`ros-gz` already installed),
MoveIt 2 demo, the `legalaspro/so101-ros-physical-ai` bridge (teleop + episode recorder + rosbag→LeRobot),
LeRobot-in-24.04 consolidation.

---

## 6. Standing risks to keep in view

1. **Nothing about real serial I/O has been exercised.** Every claim above is mock-hardware or
   path-resolution. Treat the first real launch as an experiment, not a routine.
2. **Two masters of the servo EEPROM.** LeRobot writes `Homing_Offset`; the ROS driver *can* write it too
   (`homing_offset` param). Passing it would silently invalidate LeRobot's stored calibration — the converter
   therefore leaves it out and reports the disagreement instead.
3. **usbipd = extra hop.** 6 servos at 50 Hz is ~8 kB/s, comfortably within USB/IP, but latency spikes are
   possible; if `sync_read` fails under load the fallback is native Ubuntu.
4. **One distro owns the arm at a time** — LeRobot sessions (22.04) and ROS sessions (24.04) mean an
   explicit `usbipd detach` + re-`attach`.
5. **Sub-50 Hz motion is not "slow motion".** The first trajectory should be a single joint, small delta,
   hand on the 12 V PSU.


---

## 7. Evening session — first contact with the real follower (20:50-21:20)

Hardware finally on the bench. **The arm enumerates; no servo answers.**

```
[20:59]  usbipd list → 2-1  1a86:55d3  USB-Enhanced-SERIAL CH343 (COM<n>)   Not shared
         usbipd bind --busid 2-1   (admin, UAC accepted)  → STATE: Shared   [one-time step done]
         usbipd attach --wsl Ubuntu-24.04 --busid 2-1     → attached
         NOTE: usbipd 5.3 says the distro argument is optional and the device becomes visible to
         ALL WSL2 distros. Confirmed: /dev/ttyACM0 appears in both Ubuntu-24.04 and Ubuntu 22.04.
         (The "one distro owns the arm" caveat in the runbook is therefore obsolete for 5.3.)
[21:01]  Ubuntu-24.04: /dev/ttyACM0 = crw-rw---- root:dialout → chmod 666 OK
[21:05]  read_servo_ticks.py (22.04 distro) failed twice on missing LeRobot extras:
           ImportError 'feetech-servo-sdk'  → pip install feetech-servo-sdk  (torch untouched: 2.11.0+cu126, cuda True)
           ImportError 'deepdiff'           → pip install deepdiff
         then:   RuntimeError: FeetechMotorsBus motor check failed on '/dev/ttyACM0'
                 Missing motor IDs: 1..6 (expected model 777); Full found motor list: {}
[21:10]  scan_servo_bus.py (ids 1..20 × 6 baudrates, via LeRobot) → nothing answered anywhere
[21:18]  CONTROL TEST — detached the device and ran servo_bus_ping.py (pyserial-only) natively on
         Windows COM<n>, i.e. with USB/IP completely out of the path:
                1000000 / 500000 / 250000 / 115200 / 57600 baud → NOTHING answered
```

**Conclusion so far: USB/IP, WSL and the ROS side are exonerated — the fault is on the servo side
of the chain (power or the serial daisy chain).** The adapter chip enumerates over USB (that is why
`/dev/ttyACM0` and `COM<n>` exist), but the servos are not talking.

Next physical checks (in order): 12 V PSU actually on and seated at the controller board →
STS3215 LEDs lit → 3-pin chain seated at the board and at motor 1 → each hop of the chain
(they are in series, one unseated connector kills everything downstream). Also confirm the
follower is on the **12 V** supply, not the leader's 5 V one.

New tools from this session: `ros2/tools/scan_servo_bus.py` (LeRobot-wide ID/baud scan) and
`ros2/tools/servo_bus_ping.py` (pyserial-only raw ping — runs on Windows COM ports too, which is
the fast way to iterate on a wiring/power fault without going through WSL).

### 7b. PSU reseated → bus wakes, but only one servo (21:2x)

User: "I have plugged in the PSU — it was not fully plugged in." After that:

```
single scan : id 1 ANSWERED  raw=ff ff 01 02 00 fc  err=0   (clean protocol-1.0 ping reply)
repeat x6   : id 1 answered 2 of 6 attempts
next scan   : nothing answered
watch 420 s : id 1 flickers in/out (stable stretches of 30-200 s, then silent for seconds);
              ids 2..20 NEVER answered at any point in the whole 7-minute watch
```

Reading: the adapter, the PSU rail and the `usb_port` path are sound — **servo 1 answers with a valid
checksum-verified packet**. But nothing downstream of servo 1 has ever replied, and servo 1's replies are
not rock-solid (some of that may be statistical: 3 pings/id at a 50 ms timeout per pass).

Two candidate worlds, and the LED test splits them (the 3-pin cables carry power AND signal in series,
so a break after servo 1 leaves everything downstream dark):
  (a) chain break between servo 1 and servo 2 (unseated/broken 3-pin) → servos 2-6 unpowered;
  (b) servos 2-6 absent / never ID'd / never wired (partially assembled arm).
A duplicate-ID fault is ruled OUT: repeated pings to id 1 return ONE clean packet, no collisions.

Outstanding asks to the user: LED state per servo, and whether this is the follower or the leader.

---

## 8. PAUSE POINT — state of play (session 2 close-out, 2026-09-14 ~22:00)

> Resume by reading this section first. Everything above is the blow-by-blow; this is the summary.

### Where the arc stands

| Rung | Status |
|---|---|
| Explicit control, **no hardware** | pass — controllers active, a hand-written 3-point trajectory accepted and tracked exactly (`Goal finished with status: SUCCEEDED`, `error_code: 0`), `/joint_states` ends on the commanded values |
| Explicit control, **real arm** | blocked — the servo bus goes silent after servo 1 (see below) |
| See the model move (RViz) | pass, with a window-placement gotcha (`show-rviz.sh`) |
| Real motion pipeline (xacro + driver plugin + joint config) | pass — resolves, proven by launching `hardware_type:=real` with no device: the driver loads, only the serial device is missing |

### The blocker, precisely

With the arm powered (12 V PSU fully seated) and attached to WSL:

- **servo 1 answers** — a valid protocol-1.0 reply (`ff ff 01 02 00 fc`, err 0), but only *sometimes*: a 7-minute live watch showed it appearing/disappearing, and a 300 ms byte dump showed mostly truncated/garbled frames (`ff 00 20 fc`) with a clean packet only occasionally.
- **servos 2-6 never answered once**, in ~100 passes, at every id 1-20 and every baudrate down to 57600.
- **All six LEDs are lit and all cables are connected** (user-confirmed) → power reaches the whole chain, so this is the DATA line, not power. The 3-pin cables carry power *and* signal in series, and the chain is board → 1 → 2 → 3 → 4 → 5 → 6 (gripper is the terminus with a single cable — confirmed correct against the official assembly doc).
- **Not a duplicate-ID fault**: repeated pings to id 1 return one clean packet, no collisions. (Caveat recorded: simultaneous replies from several servos on one id would *superimpose* rather than appear as several packets, so only a physical isolation test fully settles it.)
- **Not a VM/usbip fault**: the same scan run natively on Windows COM<n> (USB/IP out of the path) also found nothing before the PSU was seated.

Conclusion: a series break in the data path between servo 1 and servo 2, or servos 2-6 never having been re-ID'd. The LED test cannot see a half-seated connector (power pins touching, data pin not).

### Next session target (ordered)

1. **Reseat the 3-pin cable between servo 1 and servo 2, both ends.** Then rescan: Windows `python servo_bus_ping.py --port auto` (needs `PYTHONPATH=%TEMP%\pylibs`), or in WSL on `/dev/ttyACM0`.
2. **If unchanged — gripper isolation test.** Unplug the gripper's single cable from servo 5 and plug it straight into the controller board (it becomes the only servo on the bus), then scan ids 1-20:
   - answers as **6** → IDs are fine, fault is in the chain → repeat the isolation servo by servo upstream;
   - answers as **1** → this arm's servos were never re-ID'd (they ship at id 1) → run `lerobot-setup-motors` on the follower;
   - nothing → that servo or that cable is dead → swap in a known-good cable.
3. **Fetch the follower's LeRobot calibration JSON** from the lab Ubuntu box
   (`~/.cache/huggingface/lerobot/calibration/robots/so101_follower/<arm_id>.json`), drop it in `ros2/calib/`, then
   `bash ros2/wsl/make-joint-config.sh ros2/calib/<arm_id>.json`. Without it `run-real-follower.sh` refuses to start, by design.
4. Then `run-real-follower.sh /dev/ttyACM0` (typed YES) → `test-one-joint.sh wrist_roll_joint 0.10`, watching for sign/zero problems.
5. **In parallel, no hardware needed:** watch the mock arm move in RViz, and start the Phase 4 rung — a jerk-limited / S-curve trajectory generator node emitting `/joint_trajectory`, tested against mock hardware. Commands for the RViz pairing are in the runbook.

### Config fixes applied this session — one NOT yet re-verified

- **Gripper controller type was wrong and is the open item.** `gripper_controllers/GripperActionController` exists in Humble but **not** in Jazzy — the spawner died with `Loader for controller 'gripper_controller' (type …) not found` (Jazzy ships `effort_controllers/`, `position_controllers/` and `parallel_gripper_action_controller/GripperActionController`). Changed to `parallel_gripper_action_controller/GripperActionController` with params `joint` + `allow_stalling`, and the `package.xml` exec_depend updated. **A mock run after the change still listed only two active controllers** — either the spawner was still racing the check, or `allow_stalling` is not a valid parameter for that controller. Verify first thing on resume: `grep -i gripper /tmp/so101_mock_bringup.log`.
- `run-mock.sh` before/after display rewritten: it printed raw YAML in ROS's *alphabetical* joint order with a mislabeled variable, which is a good way to fool yourself about a sign flip. It now prints `joint=+0.0000` in radians plus a **"what moved"** delta line (via new `tools/joint_state_snapshot.py`), and the diff's non-zero exit no longer aborts the script under `set -e`.
- New `wsl/show-rviz.sh`: launches the viewer and force-places its window (see below).

### Environment deltas (all verified this session)

| Thing | Detail |
|---|---|
| usbipd-win | 5.3.0; **`usbipd bind --busid 2-1` done** (one-time, admin, UAC accepted) → STATE `Shared`. Adapter = `1a86:55d3` CH343, COM<n> on Windows |
| Attach syntax | `usbipd attach --wsl <distro> --busid X`. 5.3 **ignores the distro choice** — "the device will be available in all WSL 2 distributions". Verified: `/dev/ttyACM0` appears in **both** `Ubuntu-24.04` and `Ubuntu`. The old "only one distro can own the arm" caveat is obsolete |
| Re-attach needed after | every unplug/reboot (`bind` persists, `attach` does not) |
| `Ubuntu-24.04` distro | vhdx on a secondary drive, ROS 2 Jazzy + ros2_control + MoveIt 2 + ros-gz, workspace `~/so101_ws` (7 packages), discovery fix in `~/.bashrc` |
| Packages added | `xdotool`, `x11-utils` (24.04); `feetech-servo-sdk`, `deepdiff` in the **22.04** LeRobot conda env (torch untouched: 2.11.0+cu126, CUDA True); pyserial via a temp `PYTHONPATH` dir for Windows-side scans |
| Windows displays | primary panel 1280x800 at (0,0); second display 1920x1080 starting at x=1920, so WSLg places new windows on the **second** screen - off the primary panel, where RViz then comes up invisible |

### Tools added / changed this session

```
tools/servo_bus_ping.py        pyserial-only raw ping: --port auto|COM<n>|/dev/ttyACM0,
                               --also-try-bauds, --repeat N (duplicate-ID test),
                               --watch N (live appear/disappear monitor), --dump-id N (collision dump)
tools/scan_servo_bus.py        LeRobot-based wide id x baud scan with a plain-language verdict
tools/joint_state_snapshot.py  print joint=value from a /joint_states dump; --diff for "what moved"
tools/jog_one_joint.py         rewritten: moves ONE joint through the trajectory controller
                               (streaming to forward_position_controller silently no-ops — one
                               controller per command interface)
tools/read_servo_ticks.py      read-only ticks/zero check
tools/lerobot_calib_to_ros_joints.py  LeRobot calibration JSON -> driver joint_config_file
wsl/show-rviz.sh               viewer + window placement (picks the window by NAME; Qt's 1x1
                               helper windows defeat a size heuristic)
wsl/make-joint-config.sh       one-command joint config generation
windows/attach-arm.ps1         fixed: usbipd 5.x takes the distro as the VALUE of --wsl
```

### Open / parked

- **`PROJECT-CONTEXT.md` phase table still not updated** — writes to that file are protected and the approval prompt went unanswered, so Phases 0-2 were never updated there. The measured status is in this log and in `ros2/runbook-feetech-ros2-driver.md`; the table needs a deliberate edit (or approval) on resume.
- **Parked by design (staged delivery):** Gazebo (`ros-gz` installed, never launched), MoveIt 2 demos, the `legalaspro/so101-ros-physical-ai` bridge (teleop + episode recorder + rosbag→LeRobot), consolidating LeRobot into the 24.04 distro.
- **Correction of record:** the RViz window-placement fix landed *after* the first RViz attempt, so the earlier "RViz untested" note is superseded — the runbook now carries a verified row for it.
