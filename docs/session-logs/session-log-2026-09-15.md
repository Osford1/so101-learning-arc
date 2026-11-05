# Session log — 2026-09-15

> **Class: verified result.** Appended live during the session; commands and outputs are as
> they were run.

**Goal:** make the SO-101 **follower** servo bus healthy enough for explicit control
(ROS 2 Jazzy + `ros2_control` in `Ubuntu-24.04`, LeRobot 0.6.2 in `Ubuntu` 22.04).
Carried forward from `session-log-2026-09-14.md`: the arm is powered and enumerates, but
the servo bus answers only sporadically and `lerobot-setup-motors` cannot identify a motor.

**Headline:** the bus is measurably **degraded, not misconfigured**. Single servo, no
collision, bytes lost on the wire. Nothing software-side turns 20% into 100% — it is a
part-swap problem (servo / cable / board / adapter), and that is the next session target.

## 1. Two user-facing traps, both structural (now in the runbook)

| Symptom | Cause | Fix |
|---|---|---|
| `chmod: cannot access '/dev/ttyACM0': No such file or directory` | The node doesn't exist — the USB/IP attach was gone (a detach-then-forget, an unplug, or `wsl --shutdown`). Not a Linux permission problem. | Check `usbipd list` → re-run `attach-arm.ps1` → `ls /dev/ttyACM*` → *then* chmod. |
| `lerobot-find-port` → `Could not detect the port. No difference was found ([])` | Its whole method is diffing `/dev/tty*` before/after an unplug (`lerobot_find_port.py:45-64`). Under usbipd, unplugging **detaches** the device from WSL and replugging never re-attaches it, so the port it waits for can never reappear. WSL's phantom `/dev/ttyS0-7` also defeat its "exactly one port" fallback. | **Never use `lerobot-find-port` here** — always pass `--robot.port=/dev/ttyACM0` explicitly. |

## 2. What the bus actually does (all measurements, 2026-09-14/15, arm powered)

Method: send a protocol-1.0 frame, read the reply, require a **checksum-valid** frame.
Healthy STS3215 bus ≈ **100%**.

| Condition | PING valid | READ valid |
|---|---|---|
| WSL via USB/IP, 1 Mbaud | 14/40 | 2/40 |
| **Native Windows COM<n>**, 1 Mbaud | 12/40 | 2/40 |
| 250 kbaud (after TT=254) | 19/25 (76%) | 14/25 |
| 115.2 kbaud | 21/30 (70%) | 18/30 |
| 1 Mbaud, repeat run | 7-8/30-40 (17-20%) | 1-3/30-40 |

**Exonerated:** USB/IP and the WSL layer (native Windows is identical), the host OS, the baud
clock (sweeping 950k-1050k gives a flat 20-45% plateau, not a clock-error peak), the PSU
("PSU on, one cable, LED bright"), the ID hypothesis, and collisions (**0/30** responses
carried two frame headers — only one device answers id 1).

**Failure shape** (byte-level, per-exchange): the good frames are `ff ff 01 02 00 fc`; the bad
ones are *fragments* of that same frame — `01 02 00 fc` (header missing), `ff 40 20 fc`
(mangled), `00 00 fc` (tail only). Response-length histogram: `{2:2, 3:6, 4:11, 5:1, 6:10}`.
That is **byte loss on the wire**, i.e. a bandwidth-limited physical layer — consistent with
the fact that quality rises sharply as the bit rate drops.

## 3. The servo is alive and genuine — and was reachable all along

- Model read from register 3 = **777** (= STS3215, LSB-first bytes `09 03`). Reads work; they
  were merely rare at 1 Mbaud.
- **`lerobot-setup-motors` can never configure these servos**: `_find_single_motor_p0` →
  `broadcast_ping()` requires a **model number in the PING reply**, but these answer the 6-byte
  frame `ff ff 01 02 00 fc` with no model bytes. A live servo therefore looks absent. Confirms
  the 09-14 traceback was a *tool* limitation, not a hardware verdict.
- Writes DO land even when unacknowledged: `write reg7=100` → `ack: None`, `read back: 100`.
  Treat a missing ACK on this link as "unknown", then verify by reading back.

## 4. Own goal, recovered (the lesson)

While probing, I wrote EEPROM: baud index and return-delay. On **this firmware, baud index 5
= 76800 baud** (not 57600 as LeRobot's table implies), so the servo went silent at every
*standard* rate — 9 rates × ids 1-20 all empty, and a power cycle did not clear it. It was
found by hunting a **wide** range (`ros2/wsl/wide-baud-hunt.sh`, 2400 → 2 Mbaud), answering
**4/5 at 76800**. Written back to index 0 → **acknowledged** → answering at 1 Mbaud again.

**Rules:** never write a servo's EEPROM (id/baud/return-delay) over a marginal link; if a
servo goes quiet after a baud write, hunt the **full** range, not the standard six; Feetech
applies a new baud only on restart, so a power cycle is part of the procedure.

**Servo's current state (clean, verified):** id `1`, baud index `0` (1 Mbaud), model `777`,
return-delay `254` (my write of 0 did not land; harmless ~0.5 ms per reply, LeRobot overwrites
it during calibration). The degradation is **pre-existing** — 20% at 1 Mbaud was measured
before any write.

## 5. Tools written this session (in `ros2/tools/`)

- **`bus_health.py`** — the measurement that ends the guessing: PING/READ validity over N
  exchanges, failure shapes, model number, and a verdict. Run it after every hardware change.
- **`servo_regs.py`** — raw SCS register access: `probe`, `read <addr>`, `write <addr> --value`,
  `set-id`, `set-baud`. Unicast, retries, read-back verification.
- **`collision_check.py`** — detects >1 device on one id by looking for two frame headers.
- `ros2/wsl/`: `find-servo.sh` (every baud × ids 1-20, auto-activates the LeRobot env — system
  python3 in 22.04 has no pyserial), `wide-baud-hunt.sh`, `check-servo-state.sh`,
  `restore-servo-baud-76800.sh`.

## 6. NEXT SESSION TARGET — find the degraded part (2 min per attempt)

`bus_health.py` at 1 Mbaud is the judge. Healthy = ~40/40; today = 8/40.

1. **Different servo** on the same board+cable (e.g. shoulder-pan alone: unplug its downstream
   cable so it is the only thing on the bus).
   - ~40/40 → the gripper servo is the failed part; every other servo is untouched.
   - still ~8/40 → shared hardware; go to 2.
2. **Different 3-pin cable**, same servo.
3. **Leader's controller board** as the substitute (its own 5 V PSU + its own servo is the
   cleanest control: it tests board *and* adapter path with different parts).
4. Then the adapter itself (a second USB-serial dongle, or the lab Ubuntu box) — the last
   common element.

Only after the bus is clean: set ids with `servo_regs.py set-id` (one servo at a time, order
gripper 6 → wrist_roll 5 → wrist_flex 4 → elbow_flex 3 → shoulder_lift 2 → shoulder_pan 1),
then `lerobot-calibrate` → `make-joint-config.sh` → the first one-joint motion.

## 7. Standing risks / open questions

- **Unanswered:** is the gripper servo's LED lit right now? (It was "bright" before the writes.)
- The servo has been power-cycled and re-attached several times; the USB side is fine, but
  re-attach after **every** unplug — nothing about it persists.
- 12 V on the follower, 5 V on the leader — do not mix PSUs between arms.
- `PROJECT-CONTEXT.md` phase table is approval-gated; this session changes no phase status (no gate
  metric was met — the arm still cannot move under explicit control).

## 8. Full reset (end of session, user's call — not a verdict on the above)

- **Removed every LeRobot install:** conda env `lerobot` + `~/lerobot` source clone +
  `~/.cache/huggingface/lerobot` in 22.04 (~11 GB), plus the Windows `miniconda3\envs\lerobot`.
- **Purged ROS 2 Jazzy from `Ubuntu-24.04`:** `/opt/ros/jazzy` (732 MB, 439 `ros-jazzy-*`
  packages), `~/so101_ws`, ROS apt sources/keyring, `~/.bashrc` ROS + `ROS_AUTOMATIC_DISCOVERY_RANGE`
  lines, `/etc/ros`. The **distro itself is kept** — Ubuntu 24.04 + systemd is the right base for
  the new stack, and re-creating it costs a rootfs download for no gain. Script: `ros2/wsl/purge-ros2.sh`.
- **Kept deliberately:** `miniforge` (the conda installer, not LeRobot), usbipd-win +
  `windows/attach-arm.ps1` (Windows-side, stack-agnostic), and the **protocol-level tools** —
  `tools/servo_regs.py`, `tools/bus_health.py`, `tools/collision_check.py`. Those talk SCS/Feetech
  frames over a serial port, so they work under *any* stack and are what diagnosed the arm.
- **New direction:** restart from **`adityakamath/so_arm_ros2`** — ROS 2 **Jazzy** (CI matrix:
  Jazzy + Kilted), with `sts_hardware_interface` built as its own package in the workspace's `src/`;
  explicit control first, then either the LeRobot bridge or Isaac Sim.
- **The hardware did not reset.** The servo bus is still degraded (~20% frame validity at 1 Mbaud),
  so §6 (find the bad part: servo → cable → board → adapter) remains the gating item before any
  real motion. Nothing in this session met a phase gate.

**Verified after the reset** (`ros2/wsl/final-verify.sh`): `ros2` not on PATH · 0 `ros-jazzy`
packages · 0 ROS refs in `~/.bashrc` · `/opt/ros` and `~/so101_ws` gone · disk 7.3 G → **3.4 G** ·
Ubuntu 24.04.4 LTS intact · conda 26.5.3 present with **no envs** · Windows miniconda envs =
`chatbot`, `pygeartrain` (LeRobot gone).

**Left in place on purpose (say the word to remove):** the `Ubuntu-24.04` distro itself
(`wsl --unregister Ubuntu-24.04` — kept because it is the correct base for the new Jazzy stack),
`Ubuntu` 22.04 (now empty of LeRobot), and a 93 MB Windows HF cache holding the re-downloadable
`lerobot/svla_so101_pickplace` dataset.

## 9. Phase 0 — environment for the new stack (**GATE PASSED**)

Target: `adityakamath/so_arm_ros2` (ROS 2 **Jazzy**) + `sts_hardware_interface`, runbook at
`ros2/phase0-so-arm-ros2-build.md`.

- Installed `ros-jazzy-desktop` + upstream CI's full dependency set (apt via the TUNA mirror);
  `python-fcl` + `numpy-stl` via pip. Cloned both repos into `~/ros2_ws/src`.
  `colcon build` → **4 packages finished** (`sts_hardware_interface`, `so_arm_description`,
  `so_arm_control`, `so_arm_bringup`).
- **Gate evidence:** `ros2 pkg list` = **354 packages** · mock launch (`use_mock:=true`) →
  `joint_state_broadcaster` **and** `so_arm_controller` both **`active`** · **6 position + 6 velocity**
  command interfaces · `/joint_states` publishing all 6 joints · mock mode confirmed in the
  hardware's own log (`6 joints (0 read-only)`, `Mock mode enabled`).
- **Four traps found and documented** (detail in the runbook):
  1. the ros2 CLI **daemon hangs** under `networkingMode=mirrored` → use `--no-daemon`; `ros2 control`
     rejects that flag → query the controller_manager with `ros2 service call`;
  2. `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` must be in `~/.profile`, not only `~/.bashrc`
     (non-interactive shells skip `.bashrc`) or every scripted ROS call hangs;
  3. **leftover node processes poison a new launch** — a stale `/robot_description` from the purged
     stack made the new controller refuse to activate on a velocity command interface that existed;
  4. the bundled `bootstrap_external_deps.sh` pip form breaks pinocchio (**numpy ABI**); upstream CI's
     `--break-system-packages --user --ignore-installed` is required.
- **The wipe did not kill the old stack's processes.** Three `demo_nodes_cpp talker`s, the old
  `so_arm101_description` launch, its `ros2_control_node` and three `robot_state_publisher`s were
  still alive (up to 9 h) and were the root cause of the confusing failures above. Killed.
- **Still open:** real motion (P2) remains blocked by the **degraded servo bus** (~20% frame validity
  at 1 Mbaud, fragmented frames = byte loss on the wire). Unchanged by any of this software work.
