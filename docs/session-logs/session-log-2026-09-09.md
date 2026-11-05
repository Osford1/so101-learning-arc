# Session log — 2026-09-09 · SO-101 grasp-and-place experiment

> **Class: verified result.** Appended live during the session; commands and outputs are as
> they were run.

**Project:** SRT embodied-AI (SO-101) · **Phase:** 0 (hardware) + 2/3 (data & ACT training)
**Protocol:** `experiment-episodes-vs-steps.md` · **Roadmap:** `gummy-bear-roadmap.md`
**Date:** Wednesday, 2026-09-09 (CST) · **Location:** Lab (real hardware)

> LIVE log — append as events happen. This file is the source for today's report.

---

## 0. Worksheet skeleton (fill as you go)

| Field | Value |
|---|---|
| Robot | LeRobot SO-101 (leader 5V / follower 12V) |
| Task | Grasp yellow block from Box A → place into Box B (white A4, hand-drawn boxes ≈30 cm apart) |
| Ubuntu box / host | _(fill — native or WSL2?)_ |
| Arm ports | follower `ttyACM0` / leader `ttyACM1` _(confirm)_ |
| Camera | front, opencv index 0, 640×480@30 MJPG _(confirm)_ |
| Env | conda `lerobot` (py3.12, torch 2.11.0+cu126) |
| Episodes planned | **80** |
| Train (smoke) | **ACT @ 2000 steps** |
| Train (real) | **ACT @ 30 000 steps** |
| Eval N | _(decide: ≥20 quick / ≥50 headline)_ |

---

## 1. Environment & hardware bring-up

- [ ] Ubuntu/boot: native or WSL → `nvidia-smi` OK
- [ ] Arm powered: follower 12V, leader 5V → both enumerate (`lerobot-find-port` / `ls /dev/ttyACM*`)
- [ ] `sudo chmod 666 /dev/ttyACM*` done
- [ ] `lerobot-find-cameras` sees the camera
- [ ] Calibration run / valid (`lerobot-calibrate` follower + leader); deleted stale cache if errors
- [ ] `lerobot-teleoperate` shows leader→follower tracking cleanly

**Notes / errors** _(append lines here — bash outputs, exit codes, hostname, etc.):_

```
[2026-09-09] ARM-CONNECTION (repeat of yesterday): leader+follower USB-C AND the camera USB
all plugged into the laptop at once → arms won't connect. Disconnected the CAMERA USB → arms
connected immediately. Likely cause: the camera shares a USB controller/host-controller
bus with the arms and starves/drives the enumeration.
ACTION: plug arms FIRST (both USB-C), confirm they enumerate, THEN plug the camera; or put the
camera on a different USB port/hub. Don't rely on all USB devices at once. (Yesterday's failure
now explained by this, not a random glitch.)
```

---

## 2. Data collection (80 episodes)

- **STATUS: recording commenced ~2026-09-09** (calibration ok, camera ok, arms ok — camera plugged AFTER arms per above fix)
- Task as run today (user phrasing): **place a yellow block from one end of the white A4 sheet to the other end** —
  maps to protocol §2 (Box A start → Box B goal, ≈30 cm apart on the paper).
- Command used (repo_id, cameras, episode/reset time): _(paste below)_
- Scene set-up: A4 flat, arrow drawn, Box A (yellow block) near left, Box B ≈30 cm right
- Randomization: block start position varied **within Box A** each episode?  (Y/N)

**Recorded: `80 / 80` episodes complete (2026-09-09).** Interruptions / re-does / discarded runs (data quality): _(count + why)_
> Dataset details to pin down for the report: repo_id, discarded/re-done episode count, whether block start was randomized within Box A, whether the reset warning appeared, total recording wall-clock.

**Warning — known issue to watch (from `training-issue-note.md`):** consistent **reset** between episodes —
leader arm active during reset so the robot returns to rest each episode. If you get
"No policy or teleoperator provided, skipping action generation", the robot is NOT being
reset to a consistent pose → noisy initial states → bad motion. **Fix the reset, do not merely add
episodes.** Record when/if this message appears.

**Log (append):**

```
```

## 3. Training — smoke run (ACT @ 2000 steps)

- Command: `lerobot-train --dataset.repo_id=<...> --policy.type=act --steps=2000 ...`
- Result: ran OK? / error (paste) · wall-clock time · final loss / no-NaN
- **Expected per protocol §4.1 note: 2000 steps is known to be far too few** — treat this only
  as a pipeline smoke test (does it train end-to-end, is the dataset shaped right).

**Log:**
```
```

## 4. Training — real run (ACT @ 30 000 steps)

- **STATUS: COMPLETE ~2026-09-09.** ACT trained on 80 episodes at **30,000 steps**.
- **Result video:** `.../9_9_2026/30000 steps training.mp4` (23.5 s, 720×1280@30 — embedded in both EN/CN reports).
- **RESULT / conclusion:** more training steps **significantly improved** the robot's movement — it now moves **left → right** across the scene instead of staying in one place (contrast the 2,000-step run, which showed ~no effect). More steps → better movement.
- **Next session target:** train on a larger budget — **60,000 / 100,000 steps** — then evaluate on held-out start positions.
- Smoke run @2000: _(did it run? outcome? — user jumped to 30k; confirm whether the 2000 smoke happened and what it showed)_
- Command: `lerobot-train ... --steps=30000 ...`
- Result: completed? wall-clock · loss curve trend · checkpoints dir
- Any CUDA OOM / WinError 1314 (symlink, Needs Dev Mode / admin) / NaN

**Log:**
```
```

## 5. Evaluation

- Command (record with `--policy.path`, display_data=false, leader connected for reset)
- Eval N = ___
- **Success rate** = x / N   ·   held-out vs training configs
- Time-to-success per episode · mean ± std if multiple runs
- Any "File exists: .../eval_xxxx" (delete eval_* and re-run) / "mean is infinity" (match camera keywords)

**Results table (copy rows from protocol §9):**
| Phase | Policy | E | S | Success @ train | Success @ held-out | Notes |
|---|---|---|---|---|---|---|
| 1 | ACT | 80 | 30,000 | | | |

**Log:**
```
```

---

## 6. Daily summary (draft — fill at end)

- What worked / what broke / what's next (e.g. run the S-axis to 60k, or E-axis at 30/50 at S*)
- Open questions for my supervisor / next session

## 7. Issues & fixes (rollup — for the report's "issues" section)

| # | Issue | Symptom | Fix applied | Resolution |
|---|---|---|---|---|
| 1 | | | | |
