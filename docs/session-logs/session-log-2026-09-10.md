# Session log — 2026-09-10 · SO-101 grasp-and-place experiment (step axis: 60k / 100k)

> **Class: verified result.** Appended live during the session; commands and outputs are as
> they were run.

**Project:** SRT embodied-AI (SO-101) · **Phase:** 3 — training-budget axis at E = 80 (protocol §4.2 step 1)
**Protocol:** `experiment-episodes-vs-steps.md` · **Roadmap:** `gummy-bear-roadmap.md` · **Prior log:** `session-log-2026-09-09.md`
**Date:** Thursday, 2026-09-10 (CST) · **Location:** Lab (real hardware)
**Media folder for today:** `<local media folder - not published>`

> LIVE log — append as events happen. This file is the source for today's report (HTML EN+CN + docx).

---

## 0. Worksheet skeleton (fill as you go)

| Field | Value |
|---|---|
| Robot | LeRobot SO-101 (leader 5 V / follower 12 V) |
| Task | One episode = pick the yellow block from its initial position (Box A) and move it to the final position (Box B) on the white A4 sheet |
| Host / OS | _(confirm: native Ubuntu box or WSL2?)_ |
| Arm ports | follower `ttyACM0` / leader `ttyACM1` _(confirm)_ |
| Camera | front, opencv index 0, 640×480@30 MJPG _(confirm)_ |
| Env / toolchain | conda `lerobot` (py3.12, torch 2.11.0+cu126), lerobot 0.6.2 |
| Dataset | repo_id: **still not recorded — pin this down today** (E = 80 episodes) |
| Episodes | 80 / 80 — recorded 2026-09-09 (carried over, no re-recording planned today) |
| **Runs planned today** | **ACT @ 60,000 steps** (primary) → **ACT @ 100,000 steps** (if time permits) |
| Prior result (9/9) | ACT @ 30,000 steps complete → moves **left → right** instead of staying in place (2,000-step run ≈ no effect) |
| Eval N | _(decide for after training: ≥20 quick / ≥50 headline; held-out start positions)_ |

**Open questions to answer TODAY (needed by the report, hard to recover later):**
1. **`--dataset.repo_id`** used for training (yesterday's log left this blank — it must match recording/training/eval).
2. Is 60k a **fresh run from scratch** or **resumed** from the 30k checkpoint? (Changes how the comparison is worded.)
3. Exact training command as typed (steps, batch_size, policy.device, output_dir, job_name).
4. Wall-clock for each run + whether checkpoints were saved (`checkpoints/last`, `checkpoints/060000`).

---

## 1. Environment & hardware bring-up

- [ ] Ubuntu/boot + `nvidia-smi` OK
- [ ] Arms powered (follower 12 V, leader 5 V) → enumerate (`ls /dev/ttyACM*` = **two** devices)
- [ ] `sudo chmod 666 /dev/ttyACM*`
- [ ] Camera seen (`lerobot-find-cameras`) — **plug AFTER the arms** (see risk 1)
- [ ] Calibration valid · teleop tracking verified

**Notes / errors** _(append dated lines — outputs, exit codes, verbatim warnings):_
```
[2026-09-10 12:58] SETUP IN PROGRESS (user): "currently setting it up" — running the 60k training today, 100k if time allows.
[2026-09-10 13:07] BRING-UP DONE, TRAINING STARTED (user): ACT @ **60,000 steps is currently training**. Start of run ≈13:07 CST (wall-clock timer starts here; correct this if the run actually kicked off earlier).
                     → awaiting: exact command, repo_id, output_dir, loss curve, wall-clock, checkpoint dirs.
[2026-09-10 ~13:10] ETA (user estimate): **the 60k run should take roughly 3 hours** → finish ≈**16:07 CST**.
                     Implied rate ≈0.18 s/step ≈5.6 steps/s on the RTX 3050. Check the figure against the trainer's own it/s.
                     Planning arithmetic: 100k at that rate = **5.0 h** — so a *fresh* 100k started at 16:07 would end ≈21:07,
                     whereas extending/resuming on top of the finished 60k run costs only ~2 h more (≈18:07). Decide which one
                     the step axis is actually testing before launching (fresh run = clean S=100k model; resume = 100k continuation).
[2026-09-10 ~13:07] NOTE (remote check from the Windows laptop): no LeRobot dataset cache on this laptop's WSL2 Ubuntu
                     (`~/.cache/huggingface/lerobot` does not exist) → the dataset/training live on the native Ubuntu box.
                     repo_id cannot be recovered remotely; must come from the operator or the Ubuntu box terminal.
```

---

## 2. Data collection

- No new recording planned today — the dataset is the **80 episodes** recorded 2026-09-09.
- Task as run (operator phrasing): **place a yellow block from one end of the white A4 sheet to the other end**
  → maps to protocol §2 (Box A start → Box B goal, ≈30 cm apart).
- repo_id: **___** · Randomization within Box A: ___(Y/N — still unconfirmed)___
- Discarded / re-done episodes (count + why): ___

```
```

## 3. Training — ACT @ 60,000 steps  _(primary run today)_

- Command: `lerobot-train --dataset.repo_id=<...> --policy.type=act --steps=60000 ...`
- Result: ok / error (paste) · wall-clock · final loss trend (no NaN) · checkpoints dir
- Watch for: CUDA OOM (RTX 3050, 8 GB) · WinError 1314 (symlink / Dev Mode) · loss plateau or rise
- **Compare against:** ACT @ 30,000 (2026-09-09, moves left→right) — is the motion smoother / more reliable?

**Log:**
```
```

## 4. Training — ACT @ 100,000 steps  _(only if time permits)_

- Command · result · wall-clock · checkpoints dir · any OOM / NaN
- **CONCLUSION:** _(state the effect plainly — e.g. "60k → smoother, reached Box B more often; 100k → no further gain")_
- **NEXT SESSION TARGET:** _(e.g. evaluation at N=20 held-out starts, then episode axis E = 30/50 at S\*)_

**Log:**
```
```

## 5. Evaluation

[2026-09-10 ~16:10] **60k TRAINING FINISHED** (user: "the training is done"). Started 13:07 → ≈2h50m wall-clock,
                    matching the 3 h estimate (≈0.17–0.18 s/step). Job/dir: `outputs/train/act_so101_test/`.
[2026-09-10 ~16:15] **EVAL BLOCKED — refused to start.** First eval command:

```
lerobot-record --robot.type=so101_follower --robot.port=/dev/ttyACM0 \
  --robot.cameras='{front: {type: opencv, index_or_path: 4, width: 640, height: 480, fps: 30, fourcc: "MJPG"}}' \
  --robot.id=my_awesome_follower_arm --display_data=false \
  --dataset.repo_id=<user>/eval_test --dataset.single_task="Put yellow block into the transparent box" \
  --policy.path=outputs/train/act_so101_test/checkpoints/last/pretrained_model
```

**Error 1 (the real one):**
```
File "/.../lerobot/datasets/lerobot_dataset.py", line 668, in create
    obj.meta = LeRobotDatasetMetadata.create(
File "/.../lerobot/datasets/dataset_metadata.py", line 632, in create
    obj.root.mkdir(parents=True, exist_ok=False)
FileExistsError: [Errno 17] File exists: '/home/<user>/.cache/huggingface/lerobot/<user>/eval_test'
```
**Error 2 (a consequence, NOT a separate bug):**
```
File ".../lerobot/scripts/lerobot_record.py", line 663, in record
    dataset.push_to_hub(tags=cfg.dataset.tags, private=cfg.dataset.private)
AttributeError: 'NoneType' object has no attribute 'push_to_hub'
```

- **Root cause:** a previous eval attempt already created the dataset root `~/.cache/huggingface/lerobot/<user>/eval_test`.
  `LeRobotDataset.create` uses `exist_ok=False` → hard failure on the second attempt with the same `repo_id`.
  This is the protocol §5.4 "File exists" failure mode (`exist_ok=False`), only on the repo dir rather than an `eval_*` folder.
- **Error 2 explained:** `dataset` stayed `None` because creation aborted; the cleanup/`except` path then called
  `dataset.push_to_hub(...)` on `None`. Chasing the AttributeError is a dead end — fix the FileExistsError.
- **Good news buried in it:** the failure happened *after* the policy config was read (the dump shows
  `policy.path` + ACT hyperparameters: dim_model 512, n_action_steps 100, chunk_size 100, resnet18 backbone,
  input_features `observation.images.front` (3,480,640) + `observation.state` (6,), output `action` (6,)),
  so the 60k checkpoint at `checkpoints/last/pretrained_model` resolved and loaded. Only the eval *dataset* was blocked.

**Fixes queued for the re-run (all in one command):**
1. `rm -rf ~/.cache/huggingface/lerobot/*/eval_test` — or better, use a fresh `repo_id` per eval so each
   result is recorded separately (e.g. `<user>/eval_60k_heldout`). Clearer for the report than reusing one name.
2. Add `--dataset.push_to_hub=false` (the dumped config had **`push_to_hub: True`** → it would try to upload
   to the Hub at the end with no token).
3. The dumped config shows **`'teleop': None`** → nothing returns the arm to rest during reset. Add the leader
   (`--teleop.type=so101_leader --teleop.port=/dev/ttyACM1 --teleop.id=my_leader`) or every episode starts from
   wherever the last one ended (issue #2 below) and the success rate is meaningless.
4. Camera is on **`index_or_path: 4`**, not the `0` used when recording. Confirm it is the same physical camera in
   the same pose (`lerobot-find-cameras`) — a different viewpoint than training is a scene-mismatch confound.
5. Task string differs from training ("Put yellow block into the transparent box"). Cosmetic for ACT (no language
   input) but keep it identical anyway.

- Eval N = ___ · success = ___ / ___ · train configs vs held-out configs · time-to-success · mean ± std
- Other documented errors: `mean is infinity` (match camera `front` keyword to the recording config exactly)

**Results table (protocol §9 rows to fill):**
| Date | Phase | Policy | E | S | Success @ train | Success @ held-out | Time-to-success | Mean ± std | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-09 | 1 | ACT | 80 | 30,000 | | | | | moves left→right, not reliable |
| 2026-09-10 | 1 | ACT | 80 | 60,000 | | | | | |
| 2026-09-10 | 1 | ACT | 80 | 100,000 | | | | | _(if run)_ |

**Log:**
```
```

---

## 6. Issues & fixes (rollup — for the report)

| # | Issue | Symptom | Fix applied | Resolution |
|---|---|---|---|---|
| 1 | Arm USB vs camera USB contention | Arms won't connect when camera + both arm USB-C are plugged in at once | Plug arms first (both enumerate), then camera / separate port or hub | fixed 2026-09-09 |
| 2 | Reset between episodes | `No policy or teleoperator provided, skipping action generation` → robot not returned to rest pose → inconsistent initial states → bad motion | Keep the leader connected during record/reset so the arm returns to rest each episode | open — `'teleop': None` in today's eval config; must add the leader for eval |
| 3 | Eval won't start: `FileExistsError` on the eval dataset | `FileExistsError: [Errno 17] File exists: ~/.cache/huggingface/lerobot/<user>/eval_test` at `dataset_metadata.py:632 mkdir(exist_ok=False)`; followed by a misleading `AttributeError: 'NoneType' object has no attribute 'push_to_hub'` | Delete the existing eval dataset dir, or use a fresh `repo_id` per eval run; add `--dataset.push_to_hub=false` | diagnosed 2026-09-10 — re-running |
| 4 | Eval camera index | Eval command used `index_or_path: 4` vs `0` at recording time | Confirm same physical camera/pose via `lerobot-find-cameras` | to verify |

## 7. Daily summary (draft — fill at end)

- What worked / what broke / what's next
- Open questions for my supervisor / next session

---

## Standing risks to keep in view today (from the protocol + prior sessions)

1. **USB enumeration order** — camera + both arm USB-C at once = arms won't connect. Plug arms FIRST, confirm two `/dev/ttyACM*`, THEN the camera (or use a separate port/hub).
2. **Consistent reset** — if `No policy or teleoperator provided, skipping action generation` appears, the robot is NOT returning to rest between episodes → noisy initial states → bad motion. Fix the reset *before* blaming the step count. (See `training-issue-note.md`.)
3. **Steps ≠ data quality** — this run tests the **S axis** (optimization/fit). If 60k/100k still looks poor, the protocol says the problem is **data quality/diversity**, not training budget (§8). Do not conclude "needs more steps" twice in a row.
4. **2,000 steps is a smoke test only** — never a data point (already established 9/9).
5. **Watch the 8 GB GPU** — 100k steps at ACT batch size is hours on the RTX 3050; if OOM, lower batch size and record that as a config change.
