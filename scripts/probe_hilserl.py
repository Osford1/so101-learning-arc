import importlib.util
import sys

checks = {
    "lerobot.robots.so_follower": ("SO100FollowerConfig",),
    "lerobot.teleoperators.so_leader": ("SO100LeaderConfig",),
    "lerobot.rl.algorithms.sac": ("SAC", "SACConfig"),
    "lerobot.rewards": ("make_reward_model",),
    "lerobot.rl.gym_manipulator": ("GymManipulatorConfig", "HILSerlRobotEnvConfig"),
    "lerobot.rl.utils": ("init_manipulator_env", "init_manipulator_dataset"),
    "lerobot.model.kinematics": ("Kinematics",),
}
for mod, names in checks.items():
    ok = importlib.util.find_spec(mod) is not None
    if not ok:
        print(f"[MISSING MODULE] {mod}")
        continue
    try:
        m = __import__(mod, fromlist=names)
    except Exception as e:
        print(f"[IMPORT FAIL]   {mod}: {type(e).__name__}: {e}")
        continue
    missing = [n for n in names if not hasattr(m, n)]
    print(f"[OK] {mod}  " + ("all attrs present" if not missing else f"missing attrs {missing}"))
