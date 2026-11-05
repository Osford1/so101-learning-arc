# so101-learning-arc

I am learning robot manipulation on an SO-101 arm, from the bottom rung up: explicit control with
ROS 2, then imitation learning, then reinforcement learning. This repository is the logbook. It is
not a library — its value is the pitfalls: every error I hit on a Windows 11 + WSL2 (Windows
Subsystem for Linux 2) machine, in the order I hit it, with the command that produced it and the
fix that worked.

## State

**Learning in public, hardware-blocked.** Green: the ROS 2 Jazzy + `ros2_control` stack brings up
with both controllers active and tracks a hand-written 3-point trajectory exactly, and an ACT
policy trained on 80 teleoperation episodes at 30,000 steps moved the arm left to right across the
scene where a 2,000-step run did nothing. Red: the follower's servo bus, which answers 14 of 40
pings at 1 Mbaud over WSL and 12 of 40 on native Windows where a healthy bus answers about 100 %,
so the real arm has never moved under explicit control and the evaluation of that ACT policy never
started. **No success rate is reported anywhere in this repository, because none was measured.**

Those bus numbers, and the conditions they were taken under, in full — measured 2026-09-14 and
2026-09-15, arm powered, one servo answering, no collision. Method: send a protocol-1.0 frame, read
the reply, accept it only if the checksum is valid.

| Condition | Valid PING replies | Valid READ replies |
|---|---|---|
| WSL2 via USB/IP, 1 Mbaud | 14/40 | 2/40 |
| Native Windows, 1 Mbaud | 12/40 | 2/40 |
| 250 kbaud, after `TT=254` | 19/25 (76 %) | 14/25 |
| 115.2 kbaud | 21/30 (70 %) | 18/30 |
| 1 Mbaud, repeat run | 7-8/30-40 (17-20 %) | 1-3/30-40 |

The failing replies are *fragments* of the correct frame — a missing header, a mangled byte, a tail
only. That is byte loss on the wire, not a configuration error, and it is why quality climbs as the
bit rate falls. USB/IP is exonerated: native Windows on the same arm gives the same numbers. The
register-level evidence, and the one piece of self-inflicted damage, are in
[`docs/session-logs/session-log-2026-09-15.md`](docs/session-logs/session-log-2026-09-15.md).

<!-- TODO(owner): which machine and which run produced the 30,000-step ACT result? The dataset
repo_id was never recorded, so the run cannot be linked or reproduced from here. See
docs/owner-todos.md item 3. -->

## What you can run today

- **Reproduce the Windows 11 + WSL2 + ROS 2 Jazzy bring-up** — `ros2/wsl/install-phase0.sh`, then
  `ros2/wsl/00-install-ros-jazzy.sh` and `ros2/wsl/01-build-workspace.sh`. The stack it builds came
  up and passed its mock gate on 2026-09-14.
- **Measure a Feetech STS3215 bus before blaming your own code** — `ros2/tools/bus_health.py`. It is
  what turned "my launch file is wrong" into "the bus loses bytes on the wire".
- **Read the failures.** `docs/windows-env-setup.md` and the four files in `docs/session-logs/`
  contain roughly thirty errors that cost me real time, each with its verbatim output.

## What is measured and what is not

This repository mixes three kinds of document, and they are not equally trustworthy. Every document in `docs/`
and `docs/session-logs/` opens with a one-line banner saying which class it belongs to.

| Class | What it means | Files |
|---|---|---|
| **Verified result** | A command was run and its output is quoted. The numbers are from that run. | the four `docs/session-logs/*.md`, `docs/windows-env-setup.md`, `docs/tdmpc-pusht-rl-run.md` |
| **Checklist** | A procedure written from vendor documentation and upstream sources. Written here, but **never executed end to end on this hardware**. | `docs/so101-leader-assembly-checklist.md`, `docs/hilserl-codes3-6-runbook.md`, `ros2/runbook-feetech-ros2-driver.md` |
| **Plan** | An objective or protocol with no data yet. | `docs/gummy-bear-roadmap.md` (its banner says *plan*), `docs/experiment-episodes-vs-steps.md` (its banner says *protocol*) |

The distinction matters most for the words **HIL-SERL** (human-in-the-loop sample-efficient
reinforcement learning). If you found this repository by searching for a working hardware RL loop:
there is not one. The HIL-SERL recipe is documented in `docs/hilserl-codes3-6-runbook.md` and its
software dependencies were import-checked, but no RL policy has ever touched this hardware, and the
one learned policy that did move it was never evaluated — so nothing in this repository carries a
success rate.

## Phase status

A phase is done when its gate metric is **measured**, not when the code exists. The full table, with
the notes explaining the two rows that moved, is in [PROJECT-CONTEXT.md](PROJECT-CONTEXT.md).

| # | Phase | Gate metric | Status |
|---|---|---|---|
| 0 | Environment | ROS 2 Jazzy in WSL2, arm reachable via usbipd, simulation launches | pass |
| 1 | ROS 2 core | a node publishes `/joint_states`, the arm shows in RViz | pass in mock |
| 2 | `ros2_control` | `ros2_control` moves the real arm | **blocked** — servo bus |
| 3 | MoveIt2 | plan and execute a pick-and-place in simulation | not run |
| 4 | Trajectory planning | a generator node makes a jerk-limited move, compared against a step | not run |
| 5 | Imitation learning | dataset to trained ACT to a measured rollout | **partly exercised** — training only, no rollout measured |
| 6 | Imitation learning plus sim-to-real | a sim-augmented policy transfers better, gap quantified | not run |
| 7 | RL in simulation | the agent learns a pick task from a reward | not run |
| 8 | RL on the real arm | HIL-SERL beats the imitation baseline | **blocked** — hardware attach |
| 9 | Capstone | planner to policy to jerk-limited controller, one arm, every layer explained | not run |

One blocker sits behind rows 2, 5 and 8: the servo bus.

## Hardware

- SO-101 **follower** arm, 12 V, six Feetech STS3215 servos over a CH343 USB-serial adapter; SO-101
  **leader** arm, 5 V, used only for teleoperation during recording.
- One USB camera at OpenCV index 0, 640x480 at 30 fps, MJPG (motion JPEG).
- Host: a Windows 11 laptop with an RTX 3050 (8 GB) — marginal for Isaac Lab, which is why
  simulation work prefers Gazebo.

## Repo layout

```
so101-learning-arc/
├── README.md                 this file
├── PROJECT-CONTEXT.md        the live phase table and the environment facts
├── LICENSE                   MIT
├── THIRD-PARTY-NOTICES.md    attributions, and what was deliberately left out
├── docs/                     env setup, roadmap, runbooks, session logs, owner-todos
├── ros2/                     explicit control (see ros2/README.md)
│   ├── phase0-so-arm-ros2-build.md     the current stack — start here
│   ├── p1-ros-core-tour.md             ROS 2 core on this robot, not on turtlesim
│   ├── runbook-feetech-ros2-driver.md  the superseded stack's troubleshooting table
│   ├── tools/                          ten python probes (bus health, registers, jogging)
│   ├── windows/ · wsl/ · ws_src/       usbipd attach; install, build, bring-up; the overlay
├── scripts/                  two standalone LeRobot probes; they drive nothing
└── diagrams/                 one design sketch, not implemented
```

## Start here

1. [`docs/windows-env-setup.md`](docs/windows-env-setup.md) — the software environment.
2. [`ros2/phase0-so-arm-ros2-build.md`](ros2/phase0-so-arm-ros2-build.md) — the current ROS 2 stack.
3. [`ros2/runbook-feetech-ros2-driver.md`](ros2/runbook-feetech-ros2-driver.md) — the troubleshooting
   table. Skip its stack; read its failures.
4. [`docs/session-logs/`](docs/session-logs/) — what actually happened, in order.

### The pitfalls index

| Symptom | Cause | Covered in |
|---|---|---|
| DDS discovery finds nothing between WSL2 and Windows | `networkingMode=mirrored` in `.wslconfig` puts both on one loopback (DDS is the publish/subscribe middleware ROS 2 uses) | `ros2/runbook-feetech-ros2-driver.md`, networking section |
| Nodes see each other, then stop mid-session | `ROS_AUTOMATIC_DISCOVERY_RANGE` was set in the wrong shell; put it in `~/.profile` | `ros2/runbook-feetech-ros2-driver.md` |
| Any `ros2` CLI command hangs for a minute | the CLI daemon is wedged — use `--no-daemon` | `ros2/wsl/fix-ros2-discovery.sh` |
| A launch comes up with controllers already "active" | stale nodes from a previous run — kill them first | `ros2/wsl/kill-stale-ros.sh` |
| `lerobot-find-port` returns `No difference was found ([])` | it diffs `/dev/tty*` across an unplug, and unplugging *detaches* the device from WSL | `docs/session-logs/session-log-2026-09-15.md` §1 |
| `chmod: cannot access '/dev/ttyACM0'` | the device node does not exist: the USB/IP attach is gone, not a permissions problem | `docs/session-logs/session-log-2026-09-15.md` §1 |
| `lerobot-setup-motors` cannot find a servo that is demonstrably alive | it requires a model number in the PING reply, and these servos do not send one | `docs/session-logs/session-log-2026-09-15.md` §3 |
| A servo goes silent at every standard baud rate | on this firmware baud index 5 is 76800, not 57600 — hunt the full range | `docs/session-logs/session-log-2026-09-15.md` §4 |
| Two controllers fight over one command interface | only one can claim a joint's command interface at a time | `docs/session-logs/session-log-2026-09-14.md`, config fixes |
| `pip install lerobot` silently turns CUDA off | PyPI's torch is a CPU build and pip calls it "already satisfied" | `docs/windows-env-setup.md` §3 |
| `[WinError 1314]` while saving a checkpoint | Windows symlink privilege — enable Developer Mode | `docs/windows-env-setup.md` §3 |
| RViz opens off-screen or on the second monitor | its window placement comes from `so_arm.rviz`; launch it through the helper script (RViz is ROS 2's 3D visualiser) | `ros2/wsl/show-rviz.sh` |

## The three rungs

### Explicit control (ROS 2)

Two attempts. The first, built on a `feetech_ros2_driver` package, is documented in
`ros2/runbook-feetech-ros2-driver.md` and was purged on 2026-09-15 to restart from
[`adityakamath/so_arm_ros2`](https://github.com/adityakamath/so_arm_ros2) with
`sts_hardware_interface` built as its own package. That second stack is the current one:
`ros2/ws_src/so101_local/` is my overlay — the `ros2_control` hardware block, the controller
configuration, and the per-servo joint config.

Verified: the workspace builds (354 packages), the mock bring-up activates both
`joint_state_broadcaster` and `joint_trajectory_controller`, and a hand-written 3-point trajectory
tracks exactly — `Goal finished with status: SUCCEEDED`, `error_code: 0`. Not verified: the same
trajectory on the real arm. The bus goes silent after the first servo, and the measurements above
are why. That is a hardware problem, so I have stopped changing software in response to it.

### Imitation learning (ACT)

Eighty teleoperated episodes of a grasp-and-place task, then ACT — action chunking with a
transformer — trained at 2,000, 30,000 and 60,000 steps under an E-axis / S-axis protocol described
in `docs/experiment-episodes-vs-steps.md`. At 30,000 steps the arm moved left to right across the
scene instead of staying put; at 2,000 steps it did nothing. That is the entire imitation-learning
result in this repository.

Three limits, stated plainly. **It ran on a separate Ubuntu box, not through this arc's WSL2
stack** — the log established that by checking that no LeRobot dataset cache existed on this laptop —
so the numbers are not reproducible from anything here. **The dataset's `repo_id` was
never recorded**, so I cannot link the data. And **evaluation never started** — `lerobot-eval`
refused to run with a `FileExistsError`, and I did not get past it, so no rollout was ever scored
and no success rate exists. `docs/training-issue-note.md` is where the bad-motion investigation
started.

### Reinforcement learning (HIL-SERL, TD-MPC)

Human-in-the-loop RL is the rung this arc is aimed at, and it is the rung I have not reached. Codes
3–6 of the upstream tutorial — reward classifier, gym environment, SAC, actor/learner — are written
up in `docs/hilserl-codes3-6-runbook.md` and their LeRobot modules were import-checked on this
machine, which proves the software is present and nothing more. Robot steps are blocked on the same
bus.

What did run end to end is simulation-only: a TD-MPC2 policy on the `pusht` task, 400 steps, **0 %
success**. Zero is the expected number there and not a failure — 400 steps is far below the budget
that task needs — but it is recorded because it is the one RL run here that completed, and its
numbers are quoted from the run itself (`docs/tdmpc-pusht-rl-run.md`).

## What is not in this repo

- **Training outputs and weights** — about 634 MB of video, checkpoints and TensorBoard logs.
- **StatQuest *Neural Networks and AI* notebooks** — someone else's teaching material, pulled from a
  public fork; `docs/windows-env-setup.md` cites the chapters I studied, not the files.
- **Chinese-language course and lab documents, and their translations** — not my material, and not
  licensed for republication.
- **Graded coursework** — worked solutions to an assignment I am enrolled in, on
  instructor-provided skeleton code.
- **A private roadmap and a project tracker** — personal planning notes.

Each exclusion, with its reason, is in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Reproducing this on your own box

Prerequisites: Windows 11, an SO-101 arm, a 12 V supply, WSL2 with at least one Ubuntu distro, and
about 20 GB free.

1. `ros2/wsl/00-install-ros-jazzy.sh` then `ros2/wsl/01-build-workspace.sh` — ROS 2 Jazzy, then
   `so_arm_ros2` cloned and built with `sts_hardware_interface`.
2. `ros2/wsl/run-mock.sh` — the mock gate. Both controllers must report **active** and the example
   trajectory must finish with `error_code: 0` before you touch hardware.
3. From an **Administrator** PowerShell window, `ros2/windows/install-usbipd.ps1` then
   `ros2/windows/attach-arm.ps1` (usbipd forwards a USB device into WSL); inside WSL,
   `sudo chmod 666 /dev/ttyACM*`.
4. `ros2/tools/bus_health.py` — measure the bus **before** running any controller against it. Under
   about 95 %, stop and fix the hardware.

**Everything machine-specific in this repository is a placeholder.** `COM4` and its BUSID, the
serial device `/dev/ttyACM0`, camera index `0`, and every `/mnt/c/path/to/so101-learning-arc` are
the values this machine used. Re-derive each one: `usbipd list` for the COM port and BUSID,
`lerobot-find-cameras` for the camera index.

## Safety

This stack has no hardware emergency stop. Read this before you power an arm.

- The **12 V supply switch is the real e-stop.** Keep a hand on it, not on the mouse.
- The first motion of any new configuration is **one joint, 0.1 rad**, with the arm clear.
- **Never write servo EEPROM** — id, baud, or return delay — over a link that is losing frames. I
  did, and the servo went silent at every standard baud rate until I found it again at 76800
  (`docs/session-logs/session-log-2026-09-15.md` §4).
- The leader runs at **5 V** and the follower at **12 V**. Never swap them.
- Check the cable and the adapter before you suspect the code. Budging the connector mid-measurement
  changes the measurement.

## Licence

MIT — see [LICENSE](LICENSE). Attributions and the list of material deliberately left out are in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Credits

Nothing third-party is vendored here; the stack is used through its published interfaces.

- [`huggingface/lerobot`](https://github.com/huggingface/lerobot) — the imitation-learning and RL
  CLI, the dataset classes and the ACT implementation.
- [`adityakamath/so_arm_ros2`](https://github.com/adityakamath/so_arm_ros2) with
  `sts_hardware_interface` — the current ROS 2 stack.
- [`TheRobotStudio/SO-ARM100`](https://github.com/TheRobotStudio/SO-ARM100) — the open hardware
  design the arm is built from.
- The Seeed Studio wiki and the HuggingFace `documentation-images` dataset — assembly stills and
  videos, linked by URL only and never copied.
- *Robot Learning: A Tutorial* ([arXiv:2510.12403](https://arxiv.org/abs/2510.12403)) — the source of
  the Code 1–6 reading order and the HIL-SERL recipe.

**Written by Chen Bin** — Mechatronics B.S. (University of Melbourne), master's student in
Mechatronics at Tsinghua University, working on precision motion control.
