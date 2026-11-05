# SO-101 Leader Arm — bench assembly checklist

> **Class: checklist.** Written from the official HF guide and the SO-ARM100 repo. Followed once, on one arm; steps not marked as observed are untested here.


Sources: official HF guide (`huggingface.co/docs/lerobot/so101`), SO-ARM100 repo
(`github.com/TheRobotStudio/SO-ARM100`), Seeed wiki. This box's kit = **Pro edition**
(leader 5 V + follower 12 V, per `PROJECT-CONTEXT.md`).

---

## 0 · Pre-flight (do this BEFORE any plastic goes together)

**Motor map — the leader is the mixed-gearing arm, all 7.4 V:**

| Joint | Motor ID | SKU | Gear ratio |
|---|---|---|---|
| L1 Base / shoulder pan | 1 | STS3215-**C044** (7.4 V) | 1:191 |
| L2 Shoulder lift | 2 | STS3215-**C001** (7.4 V) | 1:345 |
| L3 Elbow flex | 3 | STS3215-**C044** (7.4 V) | 1:191 |
| L4 Wrist flex | 4 | STS3215-**C046** (7.4 V) | 1:147 |
| L5 Wrist roll | 5 | STS3215-**C046** (7.4 V) | 1:147 |
| L6 Gripper | 6 | STS3215-**C046** (7.4 V) | 1:147 |

Follower = 6x identical 12 V C018/C047, all 1:345 (F1–F6).

- [ ] Read the SKU label on every servo and **write `L1`…`L6` on the motor** (tape + marker). Swapping L1↔L3 or putting a C046 in an arm joint still "works" but the gear ratios no longer match what the joint expects (Seeed: *"servo joint IDs and gear ratios must strictly correspond"*).
- [ ] Power rule: **leader = 5 V only**, every step, including calibration. Feed a 7.4 V servo 12 V and it burns.
- [ ] 3D-printed parts: strip all support, especially out of the screw holes (small flat screwdriver). Do **not** leave support in horizontal-axis screw holes.

**Set motor IDs + baudrate first** (writes to EEPROM — once only). One motor on the board at a time, and it must not be daisy-chained to anything yet:

```bash
lerobot-find-port          # then: single-arm port = leader's
lerobot-setup-motors --teleop.type=so101_leader --teleop.port=/dev/ttyACM1
```

The script walks down the chain: `gripper`(→6) → `wrist_roll`(5) → `wrist_flex`(4) → `elbow_flex`(3) → `shoulder_lift`(2) → `shoulder_pan`(1). Check the 3-pin cable and the PSU at each prompt — the PSU plug likes to pop out while you move the board.

- [ ] All six IDs set. Then daisy-chain the 3-pin cables and run id=1 (shoulder pan) → controller board.
- [ ] Cables: **feed the 3-pin cable into a motor *before* you screw that motor into the frame** — after the fact is fiddly.

---

## 1 · Joints 1–5 (identical parts to the follower)

For **motors 1–4**: install **both** horn halves; the top horn is secured with one **M3x6**; the bottom horn needs no screws.

**Joint 1 — base**
- [ ] Place motor 1 in the base, fasten with 4x **M2x6** (2 top, 2 bottom)
- [ ] Slide on the first motor holder, 2x **M2x6** (one each side)
- [ ] Attach the shoulder part: 4x **M3x6** on top + 4x **M3x6** underneath
- [ ] Add the shoulder motor holder

**Joint 2 — shoulder lift**
- [ ] Motor 2 slides in **from the top**, 4x **M2x6**
- [ ] Upper arm: 4x **M3x6** per side

**Joint 3 — elbow**
- [ ] Insert motor 3, 4x **M2x6**
- [ ] Forearm to motor 3: 4x **M3x6** per side

**Joint 4 — wrist flex**
- [ ] Slide on motor holder 4, slide in motor 4, 4x **M2x6**

**Joint 5 — wrist roll**
- [ ] Motor 5 into the wrist holder, 2x **M2x6** front screws
- [ ] **Only one** horn on motor 5, secured with one **M3x6**
- [ ] Wrist to motor 4: 4x **M3x6** per side

---

## 2 · Leader end-effector (this is the only step that differs from the follower)

Follower gets gripper claws; leader gets a handle + trigger.

- [ ] Leader holder onto the wrist: 4x **M3x6**
- [ ] Handle to the leader holder: 1x **M2x6**
- [ ] Insert the gripper motor (L6), 2x **M2x6** per side, then one horn with an **M3x6** horn screw
- [ ] Follower trigger: 4x **M3x6**
- [ ] Cable clips / routing tidied (the SO-101 wiring change: keeps joint 3's cable from unplugging)

---

## 3 · Then: calibrate (leader on 5 V)

```bash
# WSL2: attach the arms first via usbipd (Admin PowerShell on the host), then:
sudo chmod 666 /dev/ttyACM*
lerobot-calibrate --teleop.type=so101_leader --teleop.port=/dev/ttyACM1 --teleop.id=my_awesome_leader_arm
```

Mid-range start pose, then sweep every joint through its full range when prompted.
Calibration JSON lands in `~/.cache/huggingface/lerobot/calibration/teleoperators/`.

Teleop with the follower:

```bash
lerobot-teleoperate \
  --robot.type=so101_follower --robot.port=/dev/ttyACM0 --robot.id=my_awesome_follower_arm \
  --teleop.type=so101_leader  --teleop.port=/dev/ttyACM1 --teleop.id=my_awesome_leader_arm
```

---

## Reference videos (HF-hosted)

- Joint 1 … Joint 5: `https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/lerobot/Joint{1..5}_v2.mp4`
- Leader end-effector: `.../lerobot/Leader_v2.mp4` (follower equivalent: `Gripper_v2.mp4`)
- Motor IDs: `.../lerobot/setup_motors_so101_2.mp4` · Calibration: `.../lerobot/calibrate_so101_2.mp4`
- Seeed stills: `https://files.seeedstudio.com/wiki/robotics/projects/lerobot/so101/install_L{1..23}.jpg`
- Seeed calibration-pose stills: `.../so101/cal_L{1..6}.jpg`

## PSU / safety
- Leader: 5 V 4 A · Follower: 12 V 2 A+. USB alone powers nothing — PSU **and** USB both plugged in.
- USB ordering on this box: arms first (confirm two `/dev/ttyACM*`), camera last.
- First power-up of a freshly assembled arm: hold the arm, be ready to cut power — a mis-set ID/horn offset can drive a joint to its limit immediately.
