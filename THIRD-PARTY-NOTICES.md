# Third-party notices

**No third-party source code is vendored in this repository.** Every file here was written by me,
except where a file's own header says it is derived from an upstream file. This is an attribution
file, not a licence bundle. The repository licence is MIT (see `LICENSE`).

## Libraries and tools the work depends on

| Project | Licence | Role here |
|---|---|---|
| [`huggingface/lerobot`](https://github.com/huggingface/lerobot) | Apache-2.0 | The imitation-learning and RL half: `lerobot-train`, `lerobot-record`, `lerobot-eval`, `lerobot-calibrate`, `StreamingLeRobotDataset`, the ACT policy. Referenced throughout `docs/` and `scripts/`. |
| [`adityakamath/so_arm_ros2`](https://github.com/adityakamath/so_arm_ros2) | Apache-2.0 | The current ROS 2 stack: launch files, `so_arm101_description`, and the `sts_hardware_interface` package built inside the workspace. `ros2/ws_src/so101_local/` is a local overlay on top of it. |
| `sts_hardware_interface` | Apache-2.0 | The `ros2_control` hardware interface for the Feetech STS3215 bus, built as its own package in the workspace. Part of the `so_arm_ros2` stack. |
| `feetech_ros2_driver` (superseded stack) | Apache-2.0 | The hardware interface used by the *first* ROS 2 stack, which was purged on 2026-09-15. `ros2/runbook-feetech-ros2-driver.md` is kept as the record of that attempt; the code is not in this repository. |
| [`TheRobotStudio/SO-ARM100`](https://github.com/TheRobotStudio/SO-ARM100) | Apache-2.0 | The open hardware design that the SO-101 is built from, and the source of the assembly steps that `docs/so101-leader-assembly-checklist.md` follows. |
| [Seeed Studio SO-ARM100 / SO-101 wiki](https://wiki.seeedstudio.com/lerobot_so100m_new/) | vendor documentation | Assembly stills referenced by URL only. **No image from it is copied into this repository.** |
| HuggingFace `documentation-images` dataset | — | Assembly *videos* referenced by URL only. **No video from it is copied into this repository.** |
| *Robot Learning: A Tutorial* — [arXiv:2510.12403](https://arxiv.org/abs/2510.12403) | paper | The source of the "Code 3–6" naming used in `docs/hilserl-codes3-6-runbook.md`, and the VLA-bible reading order. Cited, not reproduced. |
| [`huggingface.co/docs/lerobot`](https://huggingface.co/docs/lerobot) | Apache-2.0 docs | The HIL-SERL recipe quoted in `docs/hilserl-codes3-6-runbook.md`. |

`ros2/ws_src/so101_local/urdf/so_arm101_local.ros2_control.xacro` is derived from the upstream file
of the same role (Apache-2.0), and its own header says so. The rest of this repository is
MIT-licensed, matching `LICENSE` and the `<license>` tag in `package.xml`.

## Material deliberately excluded

Each of these is someone else's work. It is named here so that a reader who sees it referenced in
these documents knows why it is not in the repository.

| Left out | What it is | Why |
|---|---|---|
| StatQuest *Neural Networks and AI* chapter notebooks (Ch.9–14), pulled from the `AbhishMB/statquest-neural-networks-and-ai` fork | 168 files: notebooks and images from a third-party educational repository | Not my work, and no redistribution right is assumed. `docs/windows-env-setup.md` references the chapters as *study material I read*, which is why the chapter names appear there. |
| Chinese-language lab and course documents, and their English translations | Six Typst sources and six PDFs: a lab proposal, a course assignment specification, a chapter tutorial set, and a meeting record | Not my material and not licensed for republication. The meeting record also names other people, which is a reason on its own. |
| Tsinghua ML2026 coursework built on instructor-provided skeleton code | Graded assignments for a course I am enrolled in | Publishing worked solutions is an academic-integrity exposure, and the skeleton is unlicensed third-party code. |
| Training outputs and checkpoints | About 634 MB of video, checkpoints and TensorBoard logs | Size, and the only results in it are a 3-step smoke run and a 400-step simulation run. The real 80-episode runs happened on a separate Ubuntu box and were never pushed to a model hub. |
