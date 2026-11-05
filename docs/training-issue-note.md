# Training issue — bad motion after 30 episodes (WIP note)

> **Class: verified result.** Written from the ACT runs recorded in
> `session-log-2026-09-09.md` and `session-log-2026-09-10.md`; the diagnosis is mine and it was
> never confirmed.

**Date:** 2026-09-08 · **Status:** open / to investigate · **Project:** SRT embodied-AI (SO-101)

## Symptom
Trained a policy (ACT) on **30 recorded episodes**. The **motion is still poor/erratic**.

## Terminal message (verbatim)
> No policy or teleoperator provided, skipping action generation. This is likely to happen when resetting the environment without a teleop device. The robot won't be at its rest position at the start of the next episode

## What this likely means
- During episode **reset**, LeRobot commands the robot to move to a fixed/rest position. If there is **no teleop device (leader arm)** AND **no policy active during the reset window**, it **skips action generation** → the robot is **not repositioned** → it stays wherever it finished the last episode.
- **Consequence:** the next episode starts from a **wrong/inconsistent pose**, not the intended rest pose. Across many episodes the policy sees **inconsistent initial states**, which degrades learning → jerky / drifting / bad motion. This is very likely a **contributing cause** of the jerky, drifting motion, not merely a cosmetic warning.

## Candidates to check (next steps)
1. **Rest-position config:** the reset/rest joint positions (`fixed_reset_joint_positions` under the env/processor `reset` config) and `--dataset.reset_time_s`. Make sure the robot is actually commanded back to rest each episode.
2. **Teleop active during reset (record):** for `lerobot-record` (data collection) the **leader arm** must be connected/active so the robot is reset to rest between episodes.
3. **Eval reset (record with `--policy.path`):** the policy only drives during the rollout — **not during reset** — so nothing moves the robot to rest before each eval episode. This is the most likely source of the message *during evaluation*.
4. **Data quality at episode boundaries:** inconsistent start states (plus this warning) can make a 30-episode dataset noisy, so the policy can't learn smooth motion. Consider re-recording with a **consistent reset**, not merely adding more episodes on a misaligned dataset.
5. **Fix reset FIRST, then retrain:** get the rest/reset behavior correct before throwing more episodes at it. Adding data to a dataset whose episodes start from random poses won't fix the motion.

## Related
- Codes 3–6 / HIL-SERL also rely on a consistent reset.
- Runbook notes `fixed_reset_joint_positions`, `terminate_on_success`, `reset_time_s`.
