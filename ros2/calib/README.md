# Calibration file drop folder

This folder exists so the path is present in the repo. It holds no calibration data: the
follower's LeRobot calibration is machine- and arm-specific and is not published.

Drop the follower's LeRobot calibration file here.

Where it comes from (on the machine that calibrated the arm):

    ~/.cache/huggingface/lerobot/calibration/robots/so101_follower/<arm_id>.json

Both WSL distros can read this folder, so copying it here from the lab Ubuntu box
(USB drive / scp) is the easiest transfer path.

Then, inside the ROS distro:

    bash /mnt/c/path/to/so101-learning-arc/ros2/wsl/make-joint-config.sh \
      /mnt/c/path/to/so101-learning-arc/ros2/calib/<arm_id>.json

That writes `~/so101_ws/src/so101_local/config/so101_follower_joints.yaml`, which the
installed package already points at (symlink), so nothing needs rebuilding.

Expected content: one entry per joint with `id` / `range_min` / `range_max`, and
`homing_offset` left commented out on purpose. LeRobot already wrote that value into the servo
EEPROM, and writing a second one silently invalidates its calibration.
