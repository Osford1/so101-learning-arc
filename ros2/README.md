# `ros2/` — explicit control

The rung where I write the controller: ROS 2 Jazzy plus `ros2_control` talking to the follower's
Feetech STS3215 servos, so that a trajectory *I* generate is what the arm executes. No teleop
operator and no learned policy in the loop.

## Two stacks, one current

There were two attempts. Both are here, and it matters which is which.

| | **Current** | **Superseded** |
|---|---|---|
| Stack | `adityakamath/so_arm_ros2` with `sts_hardware_interface` built as its own package | a `feetech_ros2_driver` package in a hand-built workspace |
| Read | [`phase0-so-arm-ros2-build.md`](phase0-so-arm-ros2-build.md) and [`p1-ros-core-tour.md`](p1-ros-core-tour.md) | [`runbook-feetech-ros2-driver.md`](runbook-feetech-ros2-driver.md) |
| State | Workspace built; mock bring-up passes; the real arm does not move | Purged 2026-09-15 |

The superseded runbook is kept for one reason: its 20-row troubleshooting table, and its sections
on the WSL2 + usbipd mechanics, the `ROS_AUTOMATIC_DISCOVERY_RANGE` DDS trap, the zero-position
convention, and the servo-bus diagnosis in `tools/` are all still true. The stack it describes is
gone.

## What is verified, and what is not

| Claim | Status |
|---|---|
| The Jazzy workspace builds from source | pass — 354 packages, `session-log-2026-09-14.md` |
| A mock bring-up with both controllers active | pass — `joint_state_broadcaster` and `joint_trajectory_controller` both active |
| A hand-written 3-point trajectory tracks exactly | pass in mock — `Goal finished with status: SUCCEEDED`, `error_code: 0` |
| The same trajectory on the real arm | not run — the bus is degraded, so nothing has moved |
| MoveIt2, trajectory planning, the capstone | not run |

The servo bus is the single blocker. Measured 2026-09-14/15: 14 of 40 pings at 1 Mbaud over WSL and
12 of 40 on native Windows, on a healthy bus that would answer about 100 %. See
`../docs/session-logs/session-log-2026-09-15.md`.

## Layout

```
ros2/
├── README.md                        this file
├── phase0-so-arm-ros2-build.md      the current stack, end to end. Start here.
├── p1-ros-core-tour.md              ROS 2 core, learned on this robot rather than on turtlesim
├── runbook-feetech-ros2-driver.md   the superseded stack — kept for its troubleshooting table
├── so_arm.rviz                      RViz layout used by the bring-up
├── calib/                           drop folder for a LeRobot calibration file. Empty on purpose.
├── windows/                         install-usbipd.ps1, attach-arm.ps1 (run as Administrator)
├── tools/                           ten python probes: bus health, registers, jogging, ticks
├── wsl/                             the scripts I still run: install, build, mock, attach, diagnose
└── ws_src/so101_local/              the local package overlay: package.xml, URDF block, controller config
```

`wsl/diagnostics/` holds 28 one-off scripts that were written to answer a single question each
during the 2026-09-14/15 sessions, and were then kept as evidence. Read its README before running
any of them.

## Ports and paths in these scripts are placeholders

`COM4`, `/dev/ttyACM0`, camera index `0` and `/mnt/c/path/to/so101-learning-arc` are the values
this desk used. Re-derive your own: `usbipd list` for the COM port and the BUSID,
`lerobot-find-cameras` for the camera index. Never run `lerobot-find-port` here — it cannot work
under usbipd, and the reason is in the runbook's troubleshooting table.
