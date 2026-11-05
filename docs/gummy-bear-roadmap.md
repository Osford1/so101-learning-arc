# Gummy Bear Transfer — OKR/SMART Phase-Gate Roadmap

> **Class: plan.** Objectives and gate metrics only. None of these KRs has data yet; the December review date is a target, not a result.


> **Project:** SRT embodied-AI · **Robot:** LeRobot SO-101 (leader + follower) · **Task class:** deformable-object manipulation
> **Framed:** 2026-09-03 · **Method:** OKR + SMART + phase-gates

---

## Objective (the claim / direction)

**Demonstrate data-efficient manipulation of a small, deformable object (a gummy bear) on the SO-101 arm** — i.e. reach a reliable transfer task with the *fewest* teleop episodes, comparing ACT vs Diffusion Policy vs SmolVLA.

## Key Results (measurable)

| # | Key result | Measure / check |
|---|---|---|
| KR1 | ≥90% transfer success over 50 trials (bear fully in container B, no drop) by the Dec SRT review | % success over N=50 |
| KR2 | Reach KR1 in ≤150 teleop episodes (the "less data" claim) | episodes-to-success |
| KR3 | Rigid-block baseline: ≥80% over 40 trials, ~2 weeks in (de-risk) | % success over N=40 |
| KR4 | Publish the episodes→success curve for ACT vs Diffusion vs SmolVLA | plotted curve + table |

**North-star metric:** *episodes to reach the target success rate* (data-efficiency at fixed success). Secondaries: success rate, robustness across unseen configs, safety (no hardware damage).

---

## Phase-Gate Roadmap

> **Status note (added when publishing this repo):** the table below is the plan as framed on 2026-09-03, before the arm arrived. It is not the measured state. The measured status of each phase is in the top-level `README.md` and in `docs/session-logs/`.

| Phase | Goal & gate-metric | Status | Blocker |
|---|---|---|---|
| **0. Env + hardware gate** (Basic Exp 2) | Ubuntu host + SO-101 leader+follower + camera(s); `lerobot-find-cameras` + `lerobot-teleoperate` shows leader→follower tracking. **Gate: clean teleop + stable camera stream, 1 rigid episode recorded.** | blocked - needs hardware (software environment was done) | Physical arm + Ubuntu box (lead-time) |
| **1. Rigid-block baseline** (Exp 1) | Grasp a hard cube A→B reliably, collect at least 50 episodes. **Gate: ≥80% / 40 trials; dataset recorded + pushed.** | not run | Phase 0 |
| **2. Gummy-bear data protocol** | Define task (container A→B), camera, lighting; decide randomization (fixed→random start); set episode budget (≤150). **Gate: reproducible recording, ≥50 episodes.** | not run | Phase 1 |
| **3. Policy training** (Exp 3) | **ACT** → **Diffusion Policy** (from-scratch BC) on the data. **Gate: eval improves on held-out configs, no hardware crashes.** | not run | Phase 2 |
| **4. Data-efficiency comparison** (Exp 4 + 6 — *the research*) | **SmolVLA** (pretrained VLA) vs ACT vs Diffusion: episodes-to-success. **Gate: some method hits KR1 in ≤150 episodes; curve produced.** | not run | Phase 3 |
| **5. Hardening + real "complex"** | Randomize start/container/lighting; the deformable+translucent difficulty is the actual claim. **Gate: robust across unseen configs; quantify the failure modes (perception vs grasp).** | not run | Phase 4 |

**Note:** Phases 0–4 are the de-risked path; Phase 5 is where "complex" gets *earned*, not assumed. The gummy bear's hardness (translucent + deformable + sticky) is the research value — prove the pipeline on a rigid block first.

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase 0 lead-time (arm / Ubuntu / USB / power) | High | Order + set up early; it gates everything |
| Translucent-object **perception** fails (can't segment gummy bear) | High | Start rigid (Phase 1); try color/backlight; depth camera; or a colored bear |
| Deformable grasp (no rigid pose, sticky) | Med | Soft/geometric grasp; scoop; fine-tune gripper; record teleop "how to grab it" |
| Data too expensive (each episode is slow on real arm) | Med | Domain randomization, augmentation, pretrained VLA (SmolVLA) for fewer episodes |
| Sim-to-real / calibration drift | Med | Calibrate per session; keep camera+lighting fixed during collection |
| Scope creep to handshake/humanoid (Exp 5/7) | High | Anchor to the gummy-bear objective; park Exp 5/7 |

---

## Data-budget table (the thesis number)

| Method | Episodes to ≥90% (target) | Episodes collected | Success @ eval |
|---|---|---|---|
| ACT (from-scratch) | TBD | TBD | TBD |
| Diffusion Policy | TBD | TBD | TBD |
| SmolVLA (pretrained) | TBD | TBD | TBD |

*Fill this in as you train. The "less data" result = the SmolVLA row beating ACT/Diffusion's episode count at the same success.*

---

## Milestones (SMART, time-bound)

- **M0 (Phase 0):** By ~3 weeks, Ubuntu + SO-101 calibrated, teleop + a recorded episode working. *Gate: Phase 0 metrics.*
- **M1 (Phase 1):** By ~2 weeks after M0, ≥80% rigid-block success over 40 trials + dataset pushed.
- **M2 (Phase 2+3):** By ~4 weeks after M1, ≥50 gummy-bear episodes + a trained ACT policy that improves on eval.
- **M3 (Phase 4):** By the Dec SRT review, KR1 + KR2 met; episodes→success curve produced (the ICRA-style result).

---

## Already done vs. needed (quick view)

**Done:** software env (`conda lerobot`, CUDA torch, LeRobot 0.6.1 + CLI tools, gymnasium, jupyter); pipeline understood + Code 1 verified; study material staged; proposal + SO-101 + SmolVLA tutorials read.

**Still needed (in order):** physical SO-101 + Ubuntu (Phase 0) → rigid-block baseline (Phase 1) → gummy-bear data (Phase 2) → ACT/Diffusion (Phase 3) → SmolVLA data-efficiency (Phase 4) → hardening (Phase 5).

---
*This roadmap is the artifact; keep it updated at each gate.*
