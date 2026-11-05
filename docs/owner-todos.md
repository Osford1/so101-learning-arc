# Open items — for me, or for whoever reads this next

> **Class: owner notes.** What is missing and what was decided while preparing this repository;
> not a result.

Two lists. The first is work only I can do. The second is decisions that were made while preparing
this repository for publication, recorded so that nothing looks like an accident.

## 1. Only I can do these

| # | Item | Why it has to be me |
|---|---|---|
| 1 | **A bus reading after the part-swap test.** One `ros2/tools/bus_health.py` run over a healthy bus would turn the Phase 2 blocker into a resolved pitfall. | Bench work. |
| 2 | **A photo of the bench** — follower, leader, camera, 12 V supply. There is no image anywhere in this repository. | Physical access. |
| 3 | **The dataset `repo_id` for the 80 recorded episodes.** Three session logs leave it blank, so the README cannot link the data. | Only recoverable from the recording machine's terminal history. |
| 4 | **Whether the 80-episode dataset gets pushed to a model hub.** Nothing was pushed. | Account decision. |
| 5 | **The `30000 steps training.mp4` result clip** (23.5 s, 720x1280 at 30 fps) — publish it here, or leave it in the private media folder. If it is published it needs re-encoding and a size check first. | It lives in a private folder. |
| 6 | **The follower's LeRobot calibration JSON** — publish one real (sanitised) example in `ros2/calib/`, or keep the template that ships today. Recommendation: keep the template; a calibration file is arm-specific and useless to anyone else. | It only exists on the machine that calibrated the arm. |
| 7 | **Whether the research objective can be public before review.** `docs/gummy-bear-roadmap.md` states key results, a success-rate target and a December review date for a lab project. Published as a plan, with no data — but the pre-review publication call is a supervisor/policy question, not mine alone. | Lab policy. |
| 8 | **The gripper controller item.** `docs/session-logs/session-log-2026-09-14.md` records `parallel_gripper_action_controller/GripperActionController` with `allow_stalling` as *not yet re-verified* in Jazzy. Confirm it, or leave the open item standing. | Needs the stack running. |
| 9 | **A dated one-line status note** appended when this is published. The newest log is 2026-09-15 and the blocker is still open; a reader will otherwise assume the project stopped. | Only I can say what happened since. |

## 2. Decisions recorded during preparation

**The early-access product name in `diagrams/ml-rl-layer.html`.** The original sketch named a
vendor, its model and an early-access programme, plus a design-tool version string. All of that is
gone: the file is now titled "SRT ML/RL layer - typed-decision hooks" and the footer reads
*Typed-decision LLM hooks (design sketch, 2026-09-22) — not implemented*. The file was **kept**,
because that scrub leaves the diagram meaningful: the claim it makes is architectural, not
product-specific. **If the early-access access carries a confidentiality term, delete the file
instead** — nothing else in the repository depends on it.

**The maintainer email in `ros2/ws_src/so101_local/package.xml`** is the placeholder
`maintainer@example.com`. A personal address would fail the repository's own
personal-identifier check, and a placeholder is the honest thing for a package that nobody has
been asked to email. The maintainer name is the author's, and matches the README.

**Two WSL scripts were left out** of `ros2/wsl/`: a post-wipe verifier that enumerated this
machine's conda environments and HuggingFace cache, and a one-shot recovery script for a single
servo-EEPROM mistake. The mistake itself is written up as a cautionary case in
`docs/session-logs/session-log-2026-09-15.md` §4, which is more useful than the script was.

**Chinese course and lab documents, and their translations, are excluded.** They are not the
author's work and are not licensed for republication; one of them also names other people. The
exclusion is recorded in `THIRD-PARTY-NOTICES.md`. If any one of those documents turns out to be
original writing rather than a translation of someone else's, say which — the call would change
for that file alone.

**The network framing in the runbook was softened.** Where a script or runbook line explained a
failure by naming a circumvention tool and a region-specific access restriction, it now names the
mechanism instead: a local HTTP proxy on `127.0.0.1:7897`, which is what makes the mirrored-
networking DDS trap real. The technical content is unchanged.

**The coursework directory is not here.** It holds worked solutions to an assignment I am enrolled
in, on top of instructor-provided skeleton code. Dropped by default.

**The licence is MIT, not the Apache-2.0 the plan recommended.** The house style for this publish
set fixes `LICENSE` at MIT with `Copyright (c) 2026 Chen Bin`, and `package.xml` matches. Nothing
in this repository is a derived library, so the ROS 2 ecosystem's Apache-2.0 norm is not binding
here. If this ever absorbs upstream ROS code, revisit the choice.

**The bus numbers in the README are the session logs', not the plan's.** An early draft of the
opening screen quoted `8 of 40 pings`; the logs actually record 14/40 over WSL, 12/40 on native
Windows, and 7-8/30-40 on the repeat run, each with its own measurement conditions. The README
quotes the logs and states the conditions. If those numbers are ever re-measured, update the logs
first, then the README.

**StatQuest is named in the README on purpose**, in the "What is not in this repo" list, so the
personal-identifier grep reports two expected hits outside `THIRD-PARTY-NOTICES.md`. It is a
third-party product name, not personal data, and a reader who sees the chapter references in
`docs/windows-env-setup.md` needs to know why the files are absent.
