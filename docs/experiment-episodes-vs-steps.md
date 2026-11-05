# SO-101 Grasp-and-Place Experiment — Lab Protocol

> **Class: protocol.** Designed here, but no run of it was completed end to end. The only ACT training that happened is logged in `session-logs/session-log-2026-09-09.md` and `-2026-09-10.md`.


**Course / lab:** __\__  ·  **Institution:** ____
**Robot:** LeRobot SO-101 (follower + leader)  ·  **Date:** __________  ·  **Student(s):** __________

> This document is a self-contained, reproducible protocol. Follow it in order. Record every
> result in the data table (§9) so the experiment can be compared across students and runs.

---

## 1. Objective

Determine **how data volume (episodes) and training budget (steps) each affect a learned
grasp-and-place policy** on the SO-101, then compare behavior-cloning (BC) policies and,
optionally, refine the best one with reinforcement learning (HIL-SERL).

Primary research question: *what is the fewest number of teleoperation episodes needed to reach a
predefined success rate (data efficiency)?*

---

## 2. Task definition

**Environment (fixed for every run):**
- A sheet of **white A4 paper** flat on the table, oriented so "right" is a fixed, consistent
  direction (draw an arrow along the paper edge).
- **Two hand-drawn squares** on the paper:
  - **Box A (start)** — near the left; contains a **yellow block** at the start of every episode.
  - **Box B (goal)** — a second hand-drawn square, **≈30 cm to the right** of Box A.

**Task:** from the start pose, grasp the yellow block out of Box A and place it into Box B.

**Success criterion (single definition, used for every evaluation):**
> The yellow block comes to **rest inside hand-drawn Box B** (fully within its outline), it is
> **not** dropped anywhere else on the table, and **no human intervention/reset** occurred. An
> episode ends when the block is in Box B (success) or at the episode time limit (failure).

---

## 3. Prerequisites

### 3.1 Hardware
- SO-101 **follower** arm (12 V) and **leader** arm (5 V), connected via USB/Type-C.
- One **camera** (USB 3.0, direct connection — avoid hubs).
- A **white A4 sheet**, a **yellow block**, a **pen** (to draw the boxes).
- (For the RL stage only) a **gamepad** or the leader arm for human interventions.

### 3.2 Software environment (Linux/Ubuntu)
The pipeline runs on **Linux** (native Ubuntu or WSL2). Build the environment once:

```bash
# --- Miniforge (conda) + Python 3.12 ---
curl -LsSf https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o ~/miniforge.sh
bash ~/miniforge.sh -b -p ~/miniforge
~/miniforge/bin/conda init bash && source ~/.bashrc
conda create -n lerobot python=3.12 -y && conda activate lerobot

# --- LeRobot with HIL-SERL (source install from GitHub, NOT `pip install lerobot`) ---
git clone https://github.com/huggingface/lerobot.git ~/lerobot
cd ~/lerobot
pip install -e ".[hilserl]"

# --- Pin a CUDA torch that matches the GPU driver (RTX 3050 supports CUDA ≤12.9;
#     default pip installs a cu130 build that does NOT initialize) ---
pip install --index-url https://download.pytorch.org/whl/cu126 "torch==2.11.0+cu126" "torchvision==0.26.0+cu126"

# --- FFmpeg (required by torchcodec for video I/O; without it `lerobot-info`/train fail) ---
conda install -c conda-forge ffmpeg -y
```

**Verify** the environment works:
```bash
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"   # expect 2.11.0+cu126 True
python -c "import lerobot; print(lerobot.__version__)"                           # expect 0.6.x
```

> **Network note (China):** GitHub/HuggingFace may need a proxy (e.g. a localhost HTTP proxy).
> Conda/PyPI downloads are fast via Tsinghua mirrors if configured. If WSL2 is used, put
> `networkingMode=mirrored` in `%USERPROFILE%\.wslconfig` and restart WSL so the proxy is visible.

---

## 4. Experimental design

### 4.1 Variables
| Variable | Levels | Tests |
|---|---|---|
| **Episodes (E)** | 30, 50, 80 | Coverage/diversity → generalization |
| **Steps (S)** | 10,000 · 30,000 · 60,000 | Optimization → fit/smoothness |

**Fixed:** task (§2), scene (camera/lighting/table), policy type per phase, random seed where possible.
*(Note: 2,000 steps is known to be far too few regardless of episodes — the step floor starts at 10,000.)*

### 4.2 Run matrix and sequence (perform in this order)
**Matrix (ACT policy):**

| E \ S | 10,000 | 30,000 | 60,000 |
|-------|--------|--------|--------|
| **30** | — | — | — |
| **50** | — | — | — |
| **80** | 1st | 2nd | 3rd |

**Sequence:**
1. **Step axis at E = 80:** train and evaluate at **10,000 → 30,000 → 60,000** steps. Stop
   escalating once the success threshold is met on the held-out split (§6), or when two
   consecutive step levels show no improvement (plateau). The step count that works = **S\***.
2. **Episode axis at S = S\*:** train and evaluate at **E = 30 and E = 50** (E = 80 already done).
   This produces the **episodes → success curve**. The lowest E that meets the threshold is the
   **data-efficiency answer** (fewest episodes).
3. **Cross-policy comparison:** train **Diffusion, pi0, SmolVLA** at **E = 80, S = S\*** and compare
   against ACT. (Pretrained policies may need fewer steps/episodes — record that; it is a result.)
   Select the best model on the success metrics (§6), then sanity-check visually.

### 4.3 (Advanced, optional) — Reinforcement-learning refinement
If a policy reaches the threshold and time permits: use the best BC policy as the init, add a reward
classifier (Code 3), and run the actor/learner loop with human interventions (Code 4–6 / HIL-SERL).
Track **success rate** and **intervention rate** (the latter should fall as the policy improves).

---

## 5. Procedure (step by step)

### 5.1 Calibration (first session, and after any cable change)
```bash
sudo chmod 666 /dev/ttyACM*                 # allow access to the serial ports
# first USB/Type-C -> follower (ttyACM0, 12V); second -> leader (ttyACM1, 5V)
lerobot-calibrate --robot.type=so101_follower --robot.port=/dev/ttyACM0 --robot.id=my_follower
lerobot-calibrate --teleop.type=so101_leader  --teleop.port=/dev/ttyACM1 --teleop.id=my_leader
# delete ~/.cache/huggingface/lerobot/calibration/{robots,teleoperators} and re-calibrate if you see calibration errors
```

### 5.2 Data recording (teleoperate → collect episodes)
Aim for a consistent scene; randomize the block's start **position** (within Box A) across episodes;
record clean runs only (no re-grasps / no dropping outside the boxes).
```bash
lerobot-record \
  --robot.type=so101_follower --robot.port=/dev/ttyACM0 --robot.id=my_follower \
  --robot.cameras='{front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30, fourcc: "MJPG"}}' \
  --teleop.type=so101_leader --teleop.port=/dev/ttyACM1 --teleop.id=my_leader \
  --display_data=true \
  --dataset.repo_id=<username>/so101_grasp_test \
  --dataset.num_episodes=<E> \
  --dataset.single_task="Grasp the yellow block from box A and place it into box B" \
  --dataset.push_to_hub=false --dataset.episode_time_s=30 --dataset.reset_time_s=30
```
- **Resume** an interrupted recording with `--resume=true` and set `--dataset.num_episodes` to the
  number **still needed**.
- **Keep `--dataset.repo_id` identical** across recording, training, and evaluation.

### 5.3 Training
```bash
lerobot-train \
  --dataset.repo_id=<username>/so101_grasp_test \
  --policy.type=act \
  --output_dir=outputs/train/act_so101 \
  --job_name=act_so101 \
  --policy.device=cuda \
  --wandb.enable=false \
  --policy.push_to_hub=false \
  --steps=<S>
```
- For the cross-policy phase, change `--policy.type=diffusion` / `pi0` / `smolvla`.
- `--steps` default is high; use the value specified in §4.2.

### 5.4 Evaluation (run the trained policy)
Keep the **leader arm connected** (it provides the reset to Box A between episodes) and **match the
camera keywords** to the recording config.
```bash
lerobot-record \
  --robot.type=so101_follower --robot.port=/dev/ttyACM0 --robot.id=my_follower \
  --robot.cameras='{front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30, fourcc: "MJPG"}}' \
  --teleop.type=so101_leader --teleop.port=/dev/ttyACM1 --teleop.id=my_leader \
  --display_data=false \
  --dataset.repo_id=<username>/so101_grasp_eval \
  --dataset.single_task="Grasp the yellow block from box A and place it into box B" \
  --policy.path=outputs/train/act_so101/checkpoints/last/pretrained_model
```
- **Two common errors:** if you get `File exists: .../eval_xxxx`, delete the `eval_*` folder; if you get
  `mean is infinity`, make the camera `front/side` keywords match the recording config exactly.

---

## 6. Evaluation & metrics

**Eval N:** ≥20 episodes per run for a quick read; **≥50** for the headline/lab-grade claim. Same N
for every run.

**Record these for every configuration:**
1. **Success rate on training configurations** (start positions used in the demos) — did it learn the task.
2. **Success rate on held-out configurations** (start positions NOT in the demos) — generalization; the **primary** metric.
3. **Time / episode length** to success — efficiency.
4. **Variance / robustness** — run each configuration at least twice (or use a large eval N) and report
   mean ± standard deviation.

**Threshold (set before the experiment):** e.g. **≥80 % success over 40 evaluation episodes** on the
held-out split as the gate; use **≥90 % over 50** for the headline claim.

---

## 7. Notes / caveats
- **Scene consistency:** keep camera position, lighting, and table surface identical everywhere.
  A mismatch (e.g. a different-colored surface or lighting between training and evaluation) is a
  latent confound and can invalidate the comparison.
- **Data quality:** exclude anomalous demonstrations (dropping the block, re-grasping, leaving the scene).
- **"More episodes" must mean more variety** — randomize start position and approach; otherwise
  more episodes add nothing.
- **Compute:** 60,000 steps × several policies on a 6 GB GPU is hours each. Run the priority
  sequence (§4.2, steps 1–3) before expanding the matrix.

---

## 8. Expected main effect (for interpreting results)
- **Steps** mostly affect *fit*: success rises with S on the training config; if it stays low even at
  60,000 → the problem is data quality/diversity, not training budget.
- **Episodes** mostly affect *generalization*: success on the held-out config rises with E.
- **Overfitting signal:** high success on training config but low on held-out at high steps → more
  episodes or fewer steps.
- **Data-efficiency answer:** the smallest E (at adequate S*) that still meets the threshold.

---

## 9. Results table
| Date | Phase | Policy | E | S | Success @ train | Success @ held-out | Time-to-success | Mean ± std | Notes |
|---|---|---|---|---|---|---|---|---|---|
|  | 1 | ACT | 80 | 10,000 |  |  |  |  |  |
|  | 1 | ACT | 80 | 30,000 |  |  |  |  |  |
|  | 1 | ACT | 80 | 60,000 |  |  |  |  |  |
|  | 2 | ACT | 30 | S* |  |  |  |  |  |
|  | 2 | ACT | 50 | S* |  |  |  |  |  |
|  | 3 | Diffusion | 80 | S* |  |  |  |  |  |
|  | 3 | pi0 | 80 | S* |  |  |  |  |  |
|  | 3 | SmolVLA | 80 | S* |  |  |  |  |  |
|  | 4 (RL) | <best> | — | — |  |  |  |  |  |

---
*End of protocol. Fill §9 as you run. Compare data across students only if scene and task setups are identical.*
