# SO-101 learning arc — project context

This repository is the working root for the **SO-101 learning arc**: three ways to command the
*same* arm, stacked by difficulty.

```
Explicit control = you WRITE the controller      (deterministic)  -> ROS 2 / ros2_control / trajectory planning
IL               = you LEARN control from examples                -> teleop data, ACT, DP, VLA, sim-to-real
RL               = you OPTIMIZE control vs a reward               -> sim RL, then HIL-SERL on the real arm
```

Order matters: explicit control first (hardware bring-up, a "good motion" reference, and the
*scripted teacher* for autonomous imitation-learning data), then imitation learning (the research
path), then reinforcement learning (which needs the imitation baseline as a warm start).

## Anchor documents

| Doc | Path | What it is |
|---|---|---|
| Windows environment setup | [`docs/windows-env-setup.md`](docs/windows-env-setup.md) | The conda `lerobot` environment, every issue hit, and the fix that worked. |
| Learning-arc phase table | this file, `## Phase status` | The live 10-phase table. Do not advance a row without its gate metric. |
| Explicit-control build | [`ros2/phase0-so-arm-ros2-build.md`](ros2/phase0-so-arm-ros2-build.md) | The current ROS 2 Jazzy stack end to end. |
| Superseded-stack runbook | [`ros2/runbook-feetech-ros2-driver.md`](ros2/runbook-feetech-ros2-driver.md) | The first ROS 2 attempt, kept for its 20-row troubleshooting table. |
| Research objective | [`docs/gummy-bear-roadmap.md`](docs/gummy-bear-roadmap.md) | OKR/SMART phase gates and the data-efficiency claim. Plan, not result. |
| Experiment protocol | [`docs/experiment-episodes-vs-steps.md`](docs/experiment-episodes-vs-steps.md) | The E-axis / S-axis experiment design. Not completed end to end. |
| HIL-SERL runbook | [`docs/hilserl-codes3-6-runbook.md`](docs/hilserl-codes3-6-runbook.md) | Codes 3–6: reward classifier, gym env, SAC, actor/learner. |
| Session logs | [`docs/session-logs/`](docs/session-logs/) | Dated, appended live, raw output. The evidence for every number in the README. |

## Phase status (live)

A phase is done when its gate metric is **measured**, not when the code exists. Status words are
`pass`, `blocked`, `not run`. The table below was written 2026-09-10; the notes under it record
what changed after that date.

| # | Phase | Gate metric | Status |
|---|---|---|---|
| 0 | Environment | ROS 2 Jazzy in WSL2, arm via usbipd, sim launches | **pass** — see the note below |
| 1 | ROS 2 core | a node publishes `/joint_states`, the arm shows in RViz | **pass in mock** — `ros2/p1-ros-core-tour.md` |
| 2 | `ros2_control` | `ros2_control` moves the real arm | **blocked** — the servo bus answers 14 of 40 pings at 1 Mbaud over WSL and 12 of 40 natively, so this stack has never moved the real arm |
| 3 | MoveIt2 | plan and execute a pick-and-place in simulation | **not run** |
| 4 | Trajectory planning | a custom generator node produces a jerk-limited move, compared against a step | **not run** — the bridge to the MIM paper, see the roadmap's P4 |
| 5 | Imitation learning proper | dataset -> trained ACT -> measured rollout | **partly exercised** — 80 episodes and ACT trained at 2,000, 30,000 and 60,000 steps (100,000 was planned and never started), but it ran on a separate Ubuntu box and no rollout was ever measured, so there is no success rate |
| 6 | Imitation learning advanced + sim-to-real | a sim-augmented policy transfers better; the gap is quantified | **not run** |
| 7 | RL in simulation | the agent learns a pick task from a reward | **not run** |
| 8 | RL on the real arm | HIL-SERL beats the imitation baseline | **blocked** — codes 3–6 are built and verified software-side; robot steps are blocked on the hardware attach |
| 9 | Capstone | planner -> policy -> jerk-limited controller, one arm, every layer explained | **not run** |

**Notes since 2026-09-10.** Phase 0 and Phase 1 were worked on 2026-09-14: the Jazzy stack built,
a mock bring-up came up with both controllers active, and a hand-written 3-point trajectory
tracked exactly (`session-log-2026-09-14.md`). On 2026-09-15 that whole stack was purged to
restart from `adityakamath/so_arm_ros2`, and the servo bus was measured and identified as the
blocker at 14 of 40 pings at 1 Mbaud over WSL and 12 of 40 natively
(`session-log-2026-09-15.md`). Rows 0 and 1 therefore read
`pass` rather than the `not run` recorded on 2026-09-10; row 2 stays `blocked`.

**Earlier status note (2026-09-10).** The roadmap document still says *PARKED*; that line predates
this repository. Phase status here is the live truth. Do not claim a phase is done without its
gate metric.

## Environment facts (verified, don't re-derive)

- **Windows host:** conda env `lerobot` (`%USERPROFILE%\miniconda3\envs\lerobot`) — Python 3.12,
  torch 2.11.0+cu126 (CUDA OK), lerobot 0.6.1 plus all CLI tools. Details:
  `docs/windows-env-setup.md`.
- **WSL2 Ubuntu 22.04** (stopped by default) — miniforge env `lerobot` (lerobot **0.6.2**,
  `pip install -e ".[hilserl]"` from a git clone, deliberately *not* `pip install lerobot`), GPU
  passthrough verified (`cuda.is_available() == True`). Activate with
  `source ~/miniforge/etc/profile.d/conda.sh && conda activate lerobot`. Note that `bash -lc` and
  `conda run` are non-interactive, so conda is **not** auto-activated: the `source` line is needed.
- **WSL2 Ubuntu 24.04** — the second distro, added for ROS 2 Jazzy. `ros2/`.
- **Network:** the campus network does not reach `packages.ros.org`, so a local HTTP proxy on
  `127.0.0.1:7897` is used and `.wslconfig` sets `networkingMode=mirrored` so WSL2 inherits it.
  pip and conda are pointed at mirrors.
- **Hardware:** SO-101 leader (5 V) plus follower (12 V) plus one front camera
  (OpenCV index 0, 640x480 at 30 fps, MJPG). On WSL2 they are invisible until
  `usbipd bind` then `usbipd attach --wsl` from an **Administrator** PowerShell window on the host;
  after that `sudo chmod 666 /dev/ttyACM*`.
- **GPU:** RTX 3050 (8 GB, laptop-class) — marginal for Isaac Lab, so simulation work prefers
  Gazebo or EnvHub.

**USB ordering pitfall:** plug the arms in **first** and confirm two `/dev/ttyACM*` devices, and
only then plug in the camera. All three at once and the arms fail to connect.

## Working rules for this repository

- **Phase gates are the truth.** A phase is done when its gate metric is measured, not when the
  code exists. Never advance a status row on intent.
- **Report the real path.** Commands, exit codes, wall-clock time and verbatim errors go into a
  `session-log-YYYY-MM-DD.md`. Live logs are appended, never rewritten.
- **Staged delivery.** When a tangent or a good idea appears, park it as a note rather than
  building it. If the work drifts off the arc, say so and re-anchor.
- **Teaching style.** Explain a concept against the source paper *and* against this repository's
  own code. Interactive HTML visualisations land well.
- **Copy, don't move.** Files are copied into new locations, never moved out of the directory they
  were written in.

## File map

```
so101-learning-arc/
├── README.md                  start here
├── PROJECT-CONTEXT.md         this file
├── LICENSE                    Apache-2.0
├── THIRD-PARTY-NOTICES.md     attributions; no vendored third-party code
├── docs/                      environment setup, roadmap, protocols, and the session logs
├── ros2/                      explicit control: the current stack, the superseded runbook,
│                              tools/, wsl/ scripts, and the local package overlay
├── scripts/                   two standalone LeRobot probes; they drive nothing
└── diagrams/                  one design sketch
```
