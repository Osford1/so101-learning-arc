# TD-MPC Reinforcement Learning on `pusht` (no robot hardware)

> **Class: verified result.** This run completed in simulation and its numbers are quoted from the run itself. It touches no robot hardware.


**Goal:** watch an RL policy learn + score in simulation — the closest software-only
stand-in for VLA-bible Code 3–6, which needs the real SO-100 arms + Linux.

**Reality check first:** Code 3–6 (HIL-SERL, real-world RL) does **not** run here —
`lerobot.policies.sac` / `sac_reward_model` don't exist in the pip `lerobot==0.6.1`
release, and it physically drives the arm over `/dev/ttyACM*` on Ubuntu. TD-MPC (an RL
policy that **is** in 0.6.1) runs in the `pusht` sim with no hardware.

---

## Prerequisites (already satisfied on this machine)
- Conda env `lerobot` (python 3.12, torch 2.11+cu126, RTX 3050, CUDA).
- `lerobot[dataset]` + `lerobot[training]` extras (accelerate, wandb) installed.
- NO robot arm needed — `pusht` is a 2D simulation env.

## Step 0 — Enable Windows Developer Mode (one-time, needed for checkpoint save)
`lerobot-train` fails at the final checkpoint with `[WinError 1314] A required privilege
is not held` unless Developer Mode is on (or the shell runs as Admin).
- GUI: **Settings → Privacy & security → For developers → Developer Mode → On**, then restart/re-login.
- or PowerShell (as Admin):
  `reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"`

## Step 1 — Activate + sanity check
```bash
conda activate lerobot
lerobot-info
```

## Step 2 — Confirm `pusht` is a valid env type
```bash
python -c "from lerobot.envs.configs import EnvConfig; print('pusht' in EnvConfig.get_known_choices())"
# → True
```

## Step 3 — Train TD-MPC (online RL in the pusht sim)
TD-MPC is an **online** model-based RL policy — it learns by *interacting with the
env*, not from a fixed dataset, so **no `--dataset.repo_id`** is needed.
```bash
lerobot-train \
  --env.type=pusht \
  --policy.type=tdmpc \
  --steps=400 \
  --wandb.enable=false \
  --policy.device=cpu \
  --output_dir=outputs/train/tdmpc_pusht
```
- On the 3050 you can use `--policy.device=cuda` instead of `--policy.device=cpu`.
- If the trainer insists it wants a dataset, append `--dataset.repo_id=lerobot/pusht` (offline fallback).

## Step 4 — Evaluate the trained policy in the sim
```bash
lerobot-eval \
  --env.type=pusht \
  --policy.path=outputs/train/tdmpc_pusht/checkpoints/last/pretrained_model \
  --eval.n_episodes=5 \
  --eval.batch_size=1 \
  --output_dir=outputs/eval_logs
```

## Verified results (from a live run on this machine — 2026-09-06)
- The TD-MPC + pusht loop **runs end-to-end, no hardware.** It trained 400 steps and
  evaluated successfully (0/3, pc_success=0.0) — the loop is wired up correctly.
- Deps that had to be installed (now already present on this box): `gym-pusht==0.1.6`,
  `pymunk==6.11.1` (+ transitive: opencv-python, scipy, scikit-image, pygame, shapely, imageio).
- **`last -> 000400` symlink worked → Developer Mode is ON**, so no `[WinError 1314]`.
- **400 steps = 0% success, which is EXPECTED.** 400 steps ≈ 0.12 epochs of a 25k-frame
  dataset, so the policy is essentially unlearned. To *see it learn* you need a much longer
  run — realistically **`--steps=50000`+** (10k–100k+), on GPU.

## Pitfalls / likely issues
- **Native paths:** if you invoke the env's python directly, use `%USERPROFILE%/miniconda3/envs/lerobot/python.exe`,
  _not_ an MSYS `/c/...` path (the Windows python can't open MSYS paths).
- **Eval crashes unless the obs size is 96×96:** without it, eval errors
  `mat1 1x512 and mat2 15488x50`. Force the eval env's image size to 96×96 (e.g. set the
  env `--env.config.image_size=96` or override the observation size config) before evaluating.
- **Missing TD-MPC deps:** if you hit a missing module on a *fresh* machine, `pip install <named-package>`
  and retry once. The two needed for pusht (`gym-pusht`, `pymunk`) are already installed here.
- **Short runs don't learn:** don't expect a good success rate from a few hundred steps.
  Use a large `--steps` (50000+) and `--policy.device=cuda` for a meaningful result.
- **Eval path:** the config might name the checkpoint dir differently (e.g. `checkpoints/000400/pretrained_model`).
  `ls outputs/train/tdmpc_pusht/checkpoints/` to confirm before eval.

## If you want to verify HIL-SERL instead (real Code 3–6)
Requires: LeRobot installed **from the GitHub repo** (not pip) + Ubuntu + the physical
SO-100 follower (12V) and leader (5V) arms + camera. Then: `lerobot-find-port` →
`sudo chmod 666 /dev/ttyACM*` → `lerobot-calibrate` both arms → `lerobot-record` demos →
train the reward classifier (Code 3) → actor (Code 4) → learner (Code 5) → orchestrate (Code 6).
WARNING - code 4/6 physically drive the real arm — needs E-stop + supervision, not unattended.
