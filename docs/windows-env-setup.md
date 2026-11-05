# Windows environment setup — conda, LeRobot, and the seven issues that cost time

Set up 2026-09-02 on a Windows 11 laptop (RTX 3050, CUDA). This is the software side of the arc:
the imitation-learning and reinforcement-learning half runs here, in a conda environment, not in
WSL2. The ROS 2 half is in `ros2/` and needs WSL2 — see `ros2/phase0-so-arm-ros2-build.md`.

**Class: verified result.** Every version below was printed by the interpreter, and every fix was
applied and then re-checked. This is the one document in `docs/` where nothing is written from
vendor documentation alone.

The purpose of the environment was *data-efficient robot manipulation*: study the transformer
chapters, do the reinforcement-learning exercises, and run LeRobot.

---

## 1. What was installed — conda env `lerobot`

```
conda activate lerobot
```

| Package | Version | Why |
|---|---|---|
| Python | 3.12.14 | LeRobot requires **≥ 3.12** (0.6.1 enforces it) |
| torch | 2.11.0+cu126 | CUDA build; LeRobot pins `torch>=2.7,<2.12` |
| torchvision | 0.26.0+cu126 | pairs with torch 2.11 |
| lerobot | 0.6.1 | HuggingFace LeRobot (the "VLA bible" pipeline) |
| torchcodec | 0.11.1 | video I/O for the `[dataset]` extra |
| gymnasium | 1.3.0 | RL envs (`FrozenLake-v1`, `CartPole-v1`) |
| jupyterlab, matplotlib, pandas, wandb, huggingface_hub, opencv (cv2), datasets, pyav | — | study + LeRobot deps |

**Verified working:** `torch.cuda.is_available() == True` on the RTX 3050, `lerobot` 0.6.1 imports,
`LeRobotDataset / ACTPolicy / get_policy_class` import, `FrozenLake-v1` + `CartPole-v1` reset OK.
All LeRobot CLI tools present: `lerobot-train`, `lerobot-record`, `lerobot-eval`,
`lerobot-calibrate`, `lerobot-find-cameras`, and the rest.

The environment lives at `%USERPROFILE%\miniconda3\envs\lerobot`.

A second environment, LeRobot **0.6.2** with the `[hilserl]` extra, was later built inside WSL2
(Ubuntu 22.04 — that side is written up in `ros2/runbook-feetech-ros2-driver.md`). It was installed from a git
clone with `pip install -e ".[hilserl]"`, deliberately *not* with `pip install lerobot`.

---

## 2. Quick sanity checks

```bash
conda activate lerobot
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
# -> 2.11.0+cu126 True   (CUDA working)

python -c "import lerobot, gymnasium; print(lerobot.__version__, gymnasium.__version__)"
# -> 0.6.1 1.3.0
```

---

## 3. Issues encountered (and fixes)

1. **LeRobot requires Python ≥ 3.12.** The first env was created with 3.11 and `pip install
   lerobot` refused. -> Recreated the env with `python=3.12`.

2. **`pip install lerobot` silently downgraded torch to the CPU build.** LeRobot pins
   `torch>=2.7,<2.12`. PyPI's torch is CPU-only, and pip considered it "already satisfied", so the
   CUDA torch was replaced by `2.11.0+cpu` and `cuda.is_available()` went to `False`.
   -> Forced a reinstall of the exact CUDA wheels from the PyTorch cu126 index:

   ```bash
   pip install --index-url https://download.pytorch.org/whl/cu126 --force-reinstall --no-deps \
       "torch==2.11.0+cu126" "torchvision==0.26.0+cu126"
   ```

   Order matters: install the CUDA torch *after* lerobot, and pin a version inside lerobot's
   allowed range.

3. **`torchcodec` version mismatch for the `[dataset]` extra.** LeRobot wants
   `torchcodec>=0.7,<0.12`, but the pytorch cu126 index only ships 0.13+. `torchcodec` is an
   FFmpeg-decode library and is independent of the CUDA build, so the compatible 0.11.1 came from
   PyPI instead: `pip install "torchcodec>=0.7,<0.12"`.

4. **Git Credential Manager blocked a public repo clone** with "Invalid username or token" on this
   machine. -> The StatQuest notebooks were pulled as a ZIP through `codeload.github.com` instead
   of `git clone`. That is why the notebook chapter references below point at a download rather
   than a checkout. Those notebooks are not republished in this repository (see
   `THIRD-PARTY-NOTICES.md`).

5. **LeRobot 0.6.1 module paths differ from older documentation.** `lerobot.common.datasets` and
   `lerobot.common.policies` are now top-level: `lerobot.datasets.*`, `lerobot.policies.*`.

6. **`lerobot-train` needs the `[training]` extra** (`accelerate`): `pip install "lerobot[training]"`.

7. **Windows symlink permission breaks the checkpoint save.** `lerobot-train` trains fine but
   throws `[WinError 1314]` while creating `checkpoints/last` — the same symlink issue as the
   HuggingFace cache warning. Fix: enable **Windows Developer Mode**
   (Settings -> Privacy & Security -> For developers -> ON), or run the terminal as Administrator.

---

## 4. Still needed — not settable on this machine

- **The physical arm.** `lerobot-record` talks to the SO-101 over Linux serial ports
  (`/dev/ttyACM0`), so it needs Linux, not bare Windows. A WSL2 Ubuntu distro exists on this
  machine as the route to a Linux LeRobot environment without dual-booting — and GPU passthrough
  had to be confirmed before relying on it (it was: `cuda.is_available() == True` inside WSL2).
  The Linux half is written up in `ros2/runbook-feetech-ros2-driver.md` and
  `ros2/phase0-so-arm-ros2-build.md`.
- **Dataset recording** (`lerobot-record` + `lerobot-calibrate`) needs the physical arm, so it
  could not be exercised here. Training on a public HuggingFace LeRobot dataset with
  `lerobot-train` can be done on this box, with the CUDA torch above.

---

## 5. Where the study material went

The transformer chapters (`chapter_09_word_embedding.ipynb` through
`chapter_14_combing_encoder_with_decoder_transformers.ipynb`) and the RL exercises
(REINFORCE, actor-critic, Q-learning, Sarsa) were study material, not part of this arc's
pipeline. Neither is republished here: one is someone else's course notebooks, the other is
graded coursework. `THIRD-PARTY-NOTICES.md` records both exclusions.
