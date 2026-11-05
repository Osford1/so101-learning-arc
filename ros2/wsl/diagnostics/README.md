# One-off diagnostics

Twenty-eight short shell scripts, each written to answer one question during the 2026-09-14 and
2026-09-15 ROS 2 sessions. They are kept as evidence of what was actually tried, not as a curated
toolset. Several supersede each other, and some were written to test a hypothesis that turned out to
be wrong.

I have not audited each file line by line, so treat the group names below as the question each
script was written to answer, not as a promise about what it does:

| Group | Files | Question |
|---|---|---|
| `diag-*.sh` | 10 | Why does the bring-up not come up? URDF, xacro, parameters, controllers, the controller daemon, the live URDF, missing packages, interfaces, and one test against the stock upstream package. |
| `phase0-*.sh` | 4 | Did the Phase 0 environment pass, and does it still pass after a clean run? |
| `p1-*.sh` | 6 | Can the Phase 1 motion path work: joint commands, a motion test, two MuJoCo attempts, one abandoned simulation attempt, and a blockers list. |
| `teach-*.sh` | 2 | Does teaching mode work without the controller daemon, and what does the command topic actually carry? |
| single-purpose | 6 | `check-live-state.sh`, `who-publishes-joint-commands.sh`, `keep-newest-rsp.sh`, `preflight-phase0.sh`, `verify-phase0.sh`, `verify-rviz-config.sh`. |

The scripts one level up in `ros2/wsl/` are the ones still worth running. The ones here are history.

Two of these (`p1-mujoco2.sh`, `p1-sim-attempt.sh`) are unfinished experiments that were never
resolved.
