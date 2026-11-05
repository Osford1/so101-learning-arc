#set document(title: "Gummy Bear Transfer — OKR/SMART Phase-Gate Roadmap")
#set page(paper: "a4", margin: (x: 1.8cm, y: 1.6cm))
#set text(font: ("Libertinus Serif", "Microsoft YaHei"), size: 10.5pt)
#set par(justify: true)
#set heading(numbering: none)

= Gummy Bear Transfer — OKR/SMART Phase-Gate Roadmap

#text(size: 9pt)[Project: SRT embodied-AI · Robot: LeRobot SO-101 (leader + follower) · Task class: deformable-object manipulation · Framed 2026-09-03 · Method: OKR + SMART + phase-gates]

== Objective (the claim / direction)

*Demonstrate data-efficient manipulation of a small, deformable object (a gummy bear) on the SO-101 arm* — i.e. reach a reliable transfer task with the *fewest* teleop episodes, comparing ACT vs Diffusion Policy vs SmolVLA.

== Key Results (measurable)

#table(
  columns: (auto, 1fr),
  [KR1], [≥90% transfer success over 50 trials (bear fully in container B, no drop) by the Dec SRT review — % success over N=50],
  [KR2], [Reach KR1 in ≤150 teleop episodes (the "less data" claim) — episodes-to-success],
  [KR3], [Rigid-block baseline: ≥80% over 40 trials, ~2 weeks in (de-risk) — % success over N=40],
  [KR4], [Publish the episodes→success curve for ACT vs Diffusion vs SmolVLA — plotted curve + table],
)

*North-star metric:* episodes to reach the target success rate (data-efficiency at fixed success). Secondaries: success rate, robustness across unseen configs, safety (no hardware damage).

== Phase-Gate Roadmap

#text(size: 9pt)[Status note added when publishing this repo: the table below is the plan as framed 2026-09-03, before the arm arrived. It is not the measured state; the measured status of each phase is in the top-level README and in docs/session-logs/.]

#table(
  columns: (1.5fr, 2.4fr, 1.1fr, 1.1fr),
  [*Phase*], [*Goal and gate-metric*], [*Status*], [*Blocker*],
  [#text(weight:"bold")[Phase 0], Env + hardware gate, (Basic Exp 2)], [Ubuntu host + SO-101 arms + camera. *Gate:* clean teleop + stable camera; 1 rigid episode recorded.], [blocked - needs hardware (software env was done)], [Physical arm + Ubuntu (lead-time)],
  [#text(weight:"bold")[Phase 1], Rigid-block baseline, (Exp 1)], [Grasp a hard cube A→B, collect ≥50 episodes. *Gate:* ≥80% / 40 trials; dataset pushed.], [not run], [Phase 0],
  [#text(weight:"bold")[Phase 2], Gummy-bear data protocol], [Define task (A→B), camera, lighting, randomization; budget ≤150. *Gate:* reproducible recording, ≥50 episodes.], [not run], [Phase 1],
  [#text(weight:"bold")[Phase 3], Policy training, (Exp 3)], [ACT then Diffusion Policy (from-scratch BC). *Gate:* eval improves on held-out configs, no crashes.], [not run], [Phase 2],
  [#text(weight:"bold")[Phase 4], Data-efficiency comparison, (Exp 4 + 6 — the research)], [SmolVLA vs ACT vs Diffusion: episodes-to-success. *Gate:* a method hits KR1 in ≤150 episodes; curve produced.], [not run], [Phase 3],
  [#text(weight:"bold")[Phase 5], Hardening + real "complex"], [Randomize start/container/lighting; the deformable+translucent difficulty is the claim. *Gate:* robust across unseen configs; quantify failure modes.], [not run], [Phase 4],
)

*Note:* Phases 0–4 are the de-risked path; Phase 5 is where "complex" gets *earned*, not assumed. The gummy bear's hardness (translucent + deformable + sticky) is the research value — prove the pipeline on a rigid block first.

== Risk register

#table(
  columns: (1fr, auto, 1fr),
  [Risk], [Likelihood], [Mitigation],
  [Phase 0 lead-time (arm / Ubuntu / USB / power)], [High], [Order + set up early; it gates everything],
  [Translucent-object perception fails], [High], [Start rigid (Phase 1); backlight/depth; or a colored bear],
  [Deformable grasp (no rigid pose, sticky)], [Med], [Soft/geometric grasp; scoop; record teleop "how to grab it"],
  [Data too expensive (slow on real arm)], [Med], [Domain randomization, augmentation, pretrained VLA (SmolVLA)],
  [Sim-to-real / calibration drift], [Med], [Calibrate per session; keep camera+lighting fixed during collection],
  [Scope creep to handshake/humanoid (Exp 5/7)], [High], [Anchor to the gummy-bear objective; park Exp 5/7],
)

== Data-budget table (the thesis number)

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  [Method], [Episodes to ≥90% (target)], [Episodes collected], [Success @ eval],
  [ACT (from-scratch)], [TBD], [TBD], [TBD],
  [Diffusion Policy], [TBD], [TBD], [TBD],
  [SmolVLA (pretrained)], [TBD], [TBD], [TBD],
)

*Fill in as you train.* The "less data" result = the SmolVLA row beating ACT/Diffusion's episode count at the same success.

== Milestones (SMART, time-bound)

- *M0 (Phase 0):* By ~3 weeks, Ubuntu + SO-101 calibrated, teleop + a recorded episode working.
- *M1 (Phase 1):* By ~2 weeks after M0, ≥80% rigid-block success over 40 trials + dataset pushed.
- *M2 (Phase 2+3):* By ~4 weeks after M1, ≥50 gummy-bear episodes + a trained ACT policy that improves on eval.
- *M3 (Phase 4):* By the Dec SRT review, KR1 + KR2 met; episodes→success curve produced (the ICRA-style result).

== Already done vs. needed (quick view)

*Done:* software env (`conda lerobot`, CUDA torch, LeRobot 0.6.1 + CLI tools, gymnasium, jupyter); pipeline understood + Code 1 verified; study material staged; proposal + SO-101 + SmolVLA tutorials read.

*Needed (in order):* physical SO-101 + Ubuntu (Phase 0) → rigid-block baseline (Phase 1) → gummy-bear data (Phase 2) → ACT/Diffusion (Phase 3) → SmolVLA data-efficiency (Phase 4) → hardening (Phase 5).

#text(size: 9pt)[*This roadmap is the artifact; keep it updated at each gate.*]
