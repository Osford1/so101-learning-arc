# Parked idea — the SO-101 draws with a pen

> **Class: plan.** An idea parked on 2026-09-20. Nothing described here has been built or
> ordered.

**Status: PARKED, 2026-09-20.** Not on the critical path. The gating item is unchanged —
the servo bus is still degraded (~20% frame validity at 1 Mbaud, `session-log-2026-09-15.md` §6),
so the arm cannot move under explicit control yet. This note exists so the question
("can it draw a pen drawing, and can it learn to?") is answered and stored, not acted on.

## The two questions, answered

1. **Explicit control draws — yes.** You write the path; nothing is learned. This is the
   same thing a pen plotter does, with an arm instead of two rails.
2. **Learned drawing — yes, three different things go by that name.** They are not
   interchangeable, and picking the wrong one is what makes this look hard.

| Reading of "implicitly learn" | What you supply | What it buys | Arc phase |
|---|---|---|---|
| Imitation (IL) | teleop demos of one shape → ACT | the policy copies your stroke, including your quirks | P5 |
| Goal-conditioned | demos + a target image / "draw a circle" → SmolVLA | one policy, many shapes | P5–6 |
| RL with an image reward | a score (camera image vs target image), no demos | strokes nobody demonstrated; can beat the teacher | P7–8 |
| A learned pen model | (stroke params → marks on paper) data | plan strokes against the *real* pen, not an ideal one | P4/P6 |

## Explicit version — the pipeline, end to end

```
drawing file → strokes (2D polylines in paper coords)
             → paper frame → robot base frame (fixed tilt, known standoff)
             → IK → joint waypoints
             → time law (MIM / jerk-limited)
             → JointTrajectory msg → joint_trajectory_controller
```

**It plugs into a slot that already exists.** `ros2/ws_src/so101_local/config/ros2_controllers_explicit.yaml`
already declares `joint_trajectory_controller` (5 joints, `position` command interface) — that is
literally the "reference-tracking slot" the file's own comment says Phase 4's generator will fill.
`forward_position_controller` is the crude alternative (stream `Float64MultiArray`, no timing).
The gripper is a **separate** controller, which is what makes the pen-lift trick below possible.

### Physical design (this is where the project succeeds or fails)

- **Pen holder, 3D-printed, clamped in the gripper jaws.** Two requirements:
  rigid in the jaw, and a **spring between jaw and pen** so the tip pushes with a small,
  bounded, constant force.
- Why the spring: the arm cannot regulate contact force (position command interface), the
  servos are hobby-grade, and the plastic has compliance. The spring absorbs all of it —
  it turns "z is off by 1.5 mm" into "line is slightly darker", not "paper torn" / "pen lifted".
- Rigid mount only, no zip-tied pen: any wobble in the holder *is* a wobble in the line.
- **Felt-tip / marker, not ballpoint.** A ballpoint's line depends on normal force and speed;
  a felt tip lays ink down on contact, so it tolerates z error and speed variation.
- **Pen up/down:** raise the arm 2–3 mm on a rigid, flat board (simplest); or, later, use the
  separate `gripper_controller` to close the jaws on a lever that lifts the pen — that removes
  the dependence on z accuracy entirely.
- **Rigid board, paper taped flat, clamped to the table.** A curling sheet is a depth-map error.

### Calibration you must do before the first line

- **Pen-tip (TCP) offset.** The tip is not the flange. Touch the tip to 3–4 marked points,
  solve for the tip's position in the flange frame. Skip this and every drawing is skewed.
- **Paper-plane pose.** Known height and tilt of the board in the base frame.
- **Work envelope.** Keep the pen near-vertical and the elbow mid-range; near the outer reach
  the arm is nearly straight and IK is stiff, so lines there come out bowed. Plan on an A5-ish
  area in front of the base, and measure your own envelope rather than trusting a spec sheet.

### Honest limits of the explicit route

- Repeatability at the tip on this class of arm is a few mm, plus backlash. Expect
  **recognisable shapes and letters ~2–3 cm tall**, not handwriting.
- It is **open-loop**: nothing checks that ink actually landed where you asked. Every error
  (worn servo, warm plastic, shifted paper) shows up silently in the drawing.
- A *fixed* shape is one command away this way. What explicit control cannot do: adapt to a
  different pen, a tilted or curved surface, a shifted sheet, or a target it has never been
  given coordinates for.

## Learned version — what it buys, and the cheap route to it

The line worth remembering: **explicit control gives you a scripted teacher.** A program that
draws shape X can run 200 episodes with nobody at the bench. Those episodes are a LeRobot
dataset, and a policy trained on them is still imitation learning — merely autonomously collected
data instead of teleop hours. That is the arc's own logic (explicit → IL) and it costs no
operator time.

- **Fixed shape, one policy:** ACT (`chunk_size=100`, ~50+ episodes, per the arc's SRT work).
  ACT has no language conditioning — one trained ACT is one shape. Two shapes = two policies.
- **Many shapes, one policy:** condition on a goal image (or a language instruction) and use
  SmolVLA. This is the version that is actually interesting as a research question.
- **RL, no demos at all:** reward = similarity between what the camera sees and the target
  image. Prior art is mature in simulation with a neural/differentiable renderer:
  Learning to Paint (arXiv:1903.04411), decoupled hierarchical RL sketching
  (arXiv:2208.04833, "Commander" picks strokes / "Stroker" draws them), sim-to-real robotic
  painting via SAC. A camera + a score is the whole environment.
- **What drawing has that gummy-bear picking does not:** an **automatic, numeric metric**.
  Drawn ink vs target image (IoU / chamfer distance) needs no human rater, so the E-axis /
  S-axis protocol of `experiment-episodes-vs-steps.md` can be reported as a curve instead of a
  success/fail judgement. If the metric ever needs to be sharper, this is the reason to prefer
  a drawing task.

## Where it belongs in the arc — do NOT add a phase

- **P4 demo (visual, cheap):** the same move, once with a step input and once through the
  jerk-limited generator, and let the pen show the difference — a shaky line vs a clean one.
  A pen line makes MIM's whole claim visible in a photo, which no block-pushing video does.
- **P5/P7 research task:** learned drawing, with the automatic metric above.
- Nothing here shortens P0–P3. It cannot start before **P2 (ros2_control moves the real arm)**,
  and P2 is blocked by the hardware, not by code.

## Unparkers (in order)

1. Find the degraded part: servo → cable → board → adapter (`session-log-2026-09-15.md` §6).
2. Set servo ids, then `lerobot-calibrate` / `make-joint-config.sh`, then the one-joint motion.
3. P1 → P2 gates.
4. 3D-print the pen holder + order a spring. (Bench work — runs in parallel with software.)
5. Pen-tip + paper-plane calibration script.
6. First line: a straight 20 mm stroke at 5 mm/s. Then a square. Then a circle via MIM.
