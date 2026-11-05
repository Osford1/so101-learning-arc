# P1 — ROS 2 core, learned on *your own* robot (not turtlesim)

**Phase:** P1 "ROS2 core" of the learning arc · **Stack:** `so_arm_ros2` (mock mode) · **Gate:** a node you
publish drives the controller, and the arm shows in RViz.

Why on your own stack: the official tutorials use turtlesim, so the mental model stays abstract. Here
every concept has a *counterpart you can point at on the arm* — a node is the IK solver, a topic is
joint state, a service is the e-stop, tf2 is where the gripper is.

---

## Before each session: bring the stack up

```bash
wsl -d Ubuntu-24.04 -u <your-wsl-user>          # Windows side
bash ~/phase0-gate.sh                 # clean bring-up; ends by leaving the stack RUNNING
```

**Every `ros2` command needs the environment, and the CLI daemon hangs on this host.**

- Shells already have ROS sourced (`.bashrc`), plus the workspace.
- Use `--no-daemon` with `list`-style verbs (`node list`, `topic list/echo/hz/info`, `param`, `service list`).
- `ros2 control <verb>` and `ros2 topic pub` **reject** `--no-daemon` — for controller queries use
  `ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers`.

---

## Rung 1 — Nodes: the processes behind the arm

```bash
ros2 node list --no-daemon
ros2 node info /so_arm_controller --no-daemon
```

**Concept:** a node = one process with one job. `/so_arm_controller` is a *controller*, not a robot
part. The stack you launched is ~11 nodes.

**Look for:** the second command prints the node's Subscribers / Publishers / Services / Action Servers.
That list *is* the node's place in the graph.

**On your arm:** `teleop_ik_node` (turns joystick motion into joint angles), `joint_trajectory_bridge`
(the safety gate), `so_arm_controller` (follows trajectories), `joint_state_broadcaster`, `record_replay_node`.

## Rung 2 — Topics: data that streams

```bash
ros2 topic list --no-daemon
ros2 topic info /joint_states --no-daemon -v
ros2 topic echo /joint_states --no-daemon --once
ros2 topic hz /joint_states --no-daemon
```

**Concept:** a topic is a named stream; publishers write, subscribers read, nobody waits for anybody.
`-v` shows the **QoS** — the delivery guarantee (reliable vs best-effort, depth/queue). Real robots care:
dropping a joint-state message is usually fine, dropping a trajectory is not.

**Look for:** `/joint_states` at ~50–100 Hz, 6 joints, `position` in **radians**.

**On your arm:** `/joint_states` is the arm's proprioception — the same numbers a learned policy
consumes as observations. That's the bridge to P5.

## Rung 3 — The command path (your robot's own pipeline)

```bash
ros2 topic info /joint_commands --no-daemon -v
ros2 topic info /so_arm_controller/joint_trajectory --no-daemon -v
ros2 service list --no-daemon | grep -iE "controller|emergency|stop"
ros2 action list --no-daemon
```

**Concept:** data flows through a *chain* of nodes, each adding something:

```
you / joystick  →  /joint_commands (JointState)
                →  joint_trajectory_bridge   ← self-collision check, velocity limits from the URDF
                →  /so_arm_controller/joint_trajectory (JointTrajectory)
                →  so_arm_controller → hardware command interfaces → servos
```

**Services** are request/response (one-off, blocking-ish) — `/emergency_stop`, controller
load/switch/list. **Actions** are long-running jobs with feedback — the trajectory controller exposes
`FollowJointTrajectory`. Rule of thumb: *stream = topic, quick question = service, long job = action.*

**On your arm:** this chain is exactly where P4's trajectory generator plugs in — it replaces
"you/joystick" with your own jerk-limited planner.

## Rung 4 — tf2: where the gripper actually is

```bash
ros2 topic echo /tf --no-daemon --once
ros2 run tf2_ros tf2_echo base_link gripper_link
ros2 run tf2_tools view_frames          # writes frames.pdf — the whole tree
```

**Concept:** every link has a pose relative to its parent; tf2 composes the chain into "where is X
relative to Y". That composition *is* forward kinematics — no matrix algebra on your side.

**Look for:** `tf2_echo` prints translation + rotation from `base_link` to `gripper_link`, updating
live. Move a joint with the command in Rung 5 and watch it change.

## Rung 5 — URDF: the robot's body as data

```bash
ros2 param get /robot_state_publisher robot_description | head -40
python3 - <<'PY'
import subprocess, re
x = subprocess.run(['ros2','param','get','/robot_state_publisher','robot_description'],
                   capture_output=True, text=True).stdout
for m in re.finditer(r'<joint name="([^"]+)" type="(\w+)">(.*?)</joint>', x, re.S):
    name, jtype, body = m.groups()
    lim = re.search(r'<limit[^>]*effort="([^"]+)"[^>]*lower="([^"]+)"[^>]*upper="([^"]+)"', body)
    print(f"{name:22s} {jtype:9s} " + (f"limits {lim.group(2)} … {lim.group(3)} rad" if lim else "(fixed)"))
PY
```

**Concept:** URDF = links + joints + limits, as XML. `robot_state_publisher` reads it, computes the
TF tree, and republishes `/robot_description` for everyone else (RViz, MuJoCo, the collision checker).

**On your arm:** these `lower`/`upper` numbers are the *only* thing stopping a command from driving a
servo into its own housing. `enforce_command_limits: true` in `control.yaml` is what enforces them.

## Exercise (the P1 gate, for real): your first node

Write a file `~/move_joint.py` and run it — this is the seed of the P4 controller:

```python
#!/usr/bin/env python3
import math, rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState

JOINTS = ['shoulder_pan_joint','shoulder_lift_joint','elbow_flex_joint',
          'wrist_flex_joint','wrist_roll_joint','gripper_joint']

class Mover(Node):
    def __init__(self):
        super().__init__('mover')
        self.pub = self.create_publisher(JointState, 'joint_commands', 10)
        self.t = 0.0
        self.create_timer(0.05, self.tick)      # 20 Hz
        self.get_logger().info('publishing a slow shoulder_pan sweep')

    def tick(self):
        self.t += 0.05
        msg = JointState()
        msg.name = JOINTS
        msg.position = [0.3 * math.sin(self.t), 0.0, 0.0, 0.0, 0.0, 0.0]
        self.pub.publish(msg)

rclpy.init()
node = Mover()
try:
    rclpy.spin(node)
except KeyboardInterrupt:
    pass
```

```bash
python3 ~/move_joint.py          # Ctrl-C to stop
```

Then, in another terminal: `ros2 topic echo /so_arm_controller/joint_trajectory --no-daemon --once`
— your node's output has become a trajectory the controller accepted.

**Note:** in mock mode the *reported* state won't follow it (mock is a state-holder, not a simulator).
The command chain is what you're proving here. Motion needs MuJoCo (blocked by an upstream ASCII-STL
asset bug) or the real arm.

## Where this leaves the arc

- **P1 learning:** the five rungs above; you can now read any ROS 2 graph.
- **P1 gate (motion):** needs MuJoCo fixed (small patch) or hardware.
- **P2:** real motion — blocked on the servo bus swap at the bench.
- **P4 seed:** the exercise node is where your own trajectory generator lands, replacing the
  sine sweep with a jerk-limited reference.
