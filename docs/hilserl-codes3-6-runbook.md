# Codes 3–6 — HIL-SERL Real-World RL (SRT project)

> **Class: checklist.** Written from the upstream tutorial and the LeRobot docs. The software-side imports were verified; no robot step was ever taken.


> What the "VLA Bible" (Robot Learning: A Tutorial, arXiv:2510.12403) Ch3 calls **Code 3–6**.
> They are the **HIL-SERL** human-in-the-loop RL recipe. Canonical doc:
> `huggingface.co/docs/lerobot/hilserl` and the repo's `docs/source/hilserl.mdx`.
> Full single-script reference: `~/lerobot/examples/tutorial/rl/hilserl_example.py`.

## What each code is
| Code | Piece | Where it lives |
|---|---|---|
| 3 | Reward classifier (vision success detector) | `lerobot.rewards.classifier.modeling_classifier.Classifier`, trained via `lerobot-train --config_path reward_classifier_train_config.json` |
| 4 | Real-robot env + demo recording | `lerobot.rl.gym_manipulator` (`make_robot_env`, `GymManipulatorConfig`), `SO100FollowerConfig`/`SO100LeaderConfig`, `lerobot-find-joint-limits`, `crop_dataset_roi` |
| 5 | SAC learner | `lerobot.rl.algorithms.sac.SACAlgorithm` (+ `GaussianActorConfig`) |
| 6 | Decoupled actor/learner loop | `python -m lerobot.rl.learner` + `python -m lerobot.rl.actor` (gRPC), or the `mp.Queue` script |

## Environment (this box)
- **Host:** WSL2 Ubuntu 22.04 on the Windows PC, RTX 3050. GPU passthrough confirmed via
  WSL2: `torch 2.11.0+cu126`, `torch.cuda.is_available()==True` (device "RTX 3050 6GB Laptop GPU").
- **Python 3.12** conda env `lerobot` (Miniforge at `~/miniforge`).
- **LeRobot** = git clone `huggingface/lerobot` → `pip install -e ".[hilserl]"` (resolved to
  **0.6.2**). NOT `pip install lerobot`. All codes 3–6 modules import OK.
- **Network:** `.wslconfig` has `networkingMode=mirrored`; proxy `127.0.0.1:PORT` auto-mirrored
  into WSL2 (`HTTP(S)_PROXY`). GitHub/conda/pip reachable; pip used a TUNA mirror.
- Activate in a shell: `source ~/miniforge/etc/profile.d/conda.sh && conda activate lerobot`.

## HARDWARE GATE (still the blocker — Phase 0)
HIL-SERL needs the **physical SO-101 leader + follower + camera**, which appear as
`/dev/ttyACM*`. WSL2 **cannot see them yet.** To attach:
1. Plug the arm (and camera) into the **Windows host** USB.
2. On **Windows** (Admin PowerShell): `usbipd bind --busid <BUS>` for each device, then
   `usbipd attach --wsl --busid <BUS>`.
3. In WSL2: `ls /dev/ttyACM*` should now show them; `sudo chmod 666 /dev/ttyACM*`.
4. Leader uses 5V, follower 12V. Reset calibration cache before first calibrate.

Until the arm is attached, only the software side of codes 3–6 (env build, reward
classifier training, SAC code) can be exercised — the robot steps cannot run.

## End-to-end workflow (once the arm is up)
All commands run inside `conda activate lerobot`, from `~/lerobot`.

**Step 0 — ports/ids.** `--robot.port=/dev/ttyACM0 --robot.id=<id>` (follower),
`--teleop.port=/dev/ttyACM1 --teleop.id=<id>` (leader). First USB = ttyACM0, second = ttyACM1.

**Step 1 — workspace bounds.** `lerobot-find-joint-limits --robot.type=so100_follower
--robot.port=/dev/ttyACM0 --robot.id=<id> --teleop.type=so100_leader
--teleop.port=/dev/ttyACM1 --teleop.id=<id>` → prints EE + joint min/max → put into
`env.processor.inverse_kinematics.end_effector_bounds`.

**Step 2 — record demos (Code 4).** Config `mode:"record"`, `dataset.repo_id`, `dataset.num_episodes_to_record`,
robot/teleop/processor. Run: `python -m lerobot.rl.gym_manipulator --config_path env_config.json`.
Press success/fail per episode; rerecord if needed.

**Step 3 — crop ROI.** `python -m lerobot.rl.crop_dataset_roi --repo-id <user>/<task>`; draw a
box per camera → `crop_params_dict` (`[top,left,h,w]`), `resize_size:[128,128]` → update config.

**Step 4 — reward classifier (Code 3).** Collect a dataset with `terminate_on_success:false`
(so success frames get reward=1), then `lerobot-train --config_path reward_classifier_train_config.json`.
Deploy: `env.processor.reward_classifier.pretrained_path=<model>`.

**Step 5 — learner (Code 5).** `python -m lerobot.rl.learner --config_path train_config_hilserl_so100.json`.

**Step 6 — actor (Code 6).** In a second shell: `python -m lerobot.rl.actor --config_path
train_config_hilserl_so100.json`. Human interventions: gamepad `space`/upper trigger or keyboard.
Watch `wandb` for intervention rate (should drop as policy improves).

## Config files — NOT in the git repo
The JSON configs the docs reference (`env_config_so100.json`, `train_config_hilserl_so100.json`,
`reward_classifier_train_config.json`) are hosted on HuggingFace, not in `huggingface/lerobot`:
- `aractingi/lerobot-example-config-files` → `env_config_so100.json`
- `lerobot/config_examples` → `rl/env_config.json`, `rl/train_config.json`, `reward_classifier/config.json`
Download, then adapt ports/ids/repo_id/crops.

## Pitfalls specific to this box
- `bash -lc` / `conda run` are NON-interactive → conda not auto-active; always
  `source ~/miniforge/etc/profile.d/conda.sh` first, or use `~/miniforge/bin/conda`.
- Direct GitHub access is blocked from this network - route through the mirrored proxy; pip used a TUNA mirror.
- Config JSON paths differ by version/checkout (main restructured; JSONs moved to HF datasets).
- On WSL2, latency via usbipd can affect the live camera/arm loop — a native Ubuntu box is
  more robust if the 10 Hz loop stutters.
