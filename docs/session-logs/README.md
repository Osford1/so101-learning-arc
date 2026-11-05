# Session logs

Four dated logs, written while the work happened. They are the primary evidence for every number
in the top-level `README.md`.

| Log | Date | What it records |
|---|---|---|
| `session-log-2026-09-09.md` | 2026-09-09 | The USB enumeration order that stops the arms connecting; 80 episodes of the yellow-block task recorded; ACT at 30,000 steps trained (the arm moved left to right instead of staying put). |
| `session-log-2026-09-10.md` | 2026-09-10 | ACT at 60,000 steps finished, about 2h50m on the RTX 3050. Evaluation refused to start with `FileExistsError`. No success rate was measured that day. |
| `session-log-2026-09-14.md` | 2026-09-14 | First ROS 2 Jazzy and `ros2_control` day: workspace built, mock bring-up passed, a hand-written 3-point trajectory tracked exactly, and the servo bus identified as the blocker. |
| `session-log-2026-09-15.md` | 2026-09-15 | Servo-bus health measured at four baud rates and on two hosts. The bus is the blocker: valid responses stay far below a healthy bus. |

Two conventions these logs follow, and which explain their shape:

- Append as events happen. Raw command output is pasted rather than summarised.
- Leave a field blank rather than fill it from memory. A blank `___` means the value was never
  captured, not that it was zero. Examples still open in `session-log-2026-09-10.md`: the dataset
  `repo_id`, and whether the 2,000-step smoke run ever happened.

No log contains another person's name, and no log is a record of someone else's session.
