# `scripts/`

Two standalone probes. Neither is part of a pipeline and neither drives the arm.

| File | What it does | What it showed |
|---|---|---|
| `demo_streaming.py` | Instantiates `StreamingLeRobotDataset` and `LeRobotDataset` on the public `lerobot/svla_so101_pickplace` dataset, prints their metadata, then pulls one sample from each. | The LeRobot 0.6.1 API difference: streaming is lazy metadata plus iteration; the cached class downloads first and then supports `ds[i]`. |
| `probe_hilserl.py` | Import-probes seven LeRobot modules (`lerobot.robots.so_follower`, `lerobot.teleoperators.so_leader`, `lerobot.rl.algorithms.sac`, `lerobot.rewards`, `lerobot.rl.gym_manipulator`, `lerobot.rl.utils`, `lerobot.model.kinematics`) and reports for each whether the module and the expected names exist. | Which pieces of the HIL-SERL stack the installed wheel actually ships. The findings are in `docs/hilserl-codes3-6-runbook.md`. |

Run either one with the `lerobot` conda environment active:

    conda activate lerobot
    python scripts/probe_hilserl.py

Both scripts import LeRobot and torch from that environment. `probe_hilserl.py` only reports
importability; it does not connect to hardware and does not train anything.
