---
name: video-to-60fps
description: >-
  Interpolates a single video to 60fps with Video2X RIFE at source resolution.
  Already ~60fps files are skipped (nothing is written). Below 60fps uses RIFE,
  not FFmpeg frame duplication. Above 60fps drops to 60 with FFmpeg. Use when the
  user wants video-to-60fps, frame interpolation, RIFE, 24 to 60, 30 to 60,
  or convert fps to 60 before video-to-4k.
disable-model-invocation: true
---

# Video to 60fps

Convert a supported video to **60fps at the source resolution** via [Video2X](https://github.com/k4yt3x/video2x) RIFE. Run this **before** `video-to-4k`.

| Spec | Value |
|------|-------|
| Frame rate | 60 FPS |
| Resolution | Unchanged |
| Already ~60fps (59.5–60.5, includes 59.94) | **Skip** — no output file |
| Below 60fps | Video2X RIFE interpolate, then snap to 60 |
| Above 60fps | FFmpeg `fps=60` drop (RIFE cannot reduce fps) |
| Video | H.265 Main10 (`libx265`, `yuv420p10le`, CRF 12) |
| Audio | AAC 320 kbps when present |
| Container | MP4 (`.mp4`, `hvc1` tag) |

## Pipeline

1. **Probe** fps with ffprobe.
2. **Already ~60?** → skip (do nothing).
3. **Above 60?** → FFmpeg drop to 60fps → `video-to-60fps/`.
4. **Below 60?** → Video2X RIFE (`-m` integer multiplier) at source resolution → FFmpeg to exact 60fps MP4 → `video-to-60fps/`.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `convert.py` through **`.dependency/python/python`**. Never use host `python` / `ffmpeg` / `video2x`.
- **Never overwrite sources.** Outputs go under `video-to-60fps/`.
- Use the bundled script — do not hand-write equivalent `video2x` / `ffmpeg` commands.
- **One file per run** — pass `--video` with a single file; repeat for each clip in a batch.
- Do **not** use FFmpeg `fps=60` duplication to fake 60fps on below-60 sources.

## Setup (first run)

Same Video2X CLI + FFmpeg + Python as `video-to-4k`. Populate `ffmpeg`, `python`, and `video2x` under `.dependency/`. Requires a **Vulkan** GPU and AVX2 CPU.

## Quick Start

```bash
.dependency/python/python .ai/video-to-60fps/convert.py --video path/to/clip.mp4
```

Example:

```
assets/video/clip.mp4          (1280×720 24fps)
  → assets/video/video-to-60fps/clip.mp4  (1280×720 60fps)
```

Already-60fps source → no output file; log `[skip]`.

Then upscale (fps kept):

```bash
.dependency/python/python .ai/video-to-4k/convert.py --video assets/video/video-to-60fps/clip.mp4
```

## Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Interpolator | RIFE `rife-v4.6` | Video2X `-p rife` |
| Multiplier | Auto | Smallest integer `-m` so `src_fps × m` is at least ~60 |
| UHD mode | Auto | `--uhd` when width ≥ 1920 |
| Already ~60fps | Skipped | No file written |

## Common Flags

`--video` · `-o` / `--output` · `--rife-model` · `--uhd` · `--gpu`

```bash
.dependency/python/python .ai/video-to-60fps/convert.py --video clip.mp4
.dependency/python/python .ai/video-to-60fps/convert.py --video clip.mp4 --gpu 0
.dependency/python/python .ai/video-to-60fps/convert.py --video clip.mp4 -o out/clip.mp4
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script only.
2. Missing Python / FFmpeg / Video2X → populate `.dependency/`, set `populated: true`, retry the same command.
3. Tell the user where `video-to-60fps/` outputs are; they swap assets manually. Skipped ~60fps files have **no** output.
4. Interpolate at **source resolution**, then `video-to-4k`. Do not 4K-upscale first.
5. Video2X `-m` is an integer. 30fps → ×2 = 60. 24fps → ×3 = 72, then FFmpeg snaps to 60.
6. Pipeline / FFmpeg / Video2X details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-to-60fps/test_convert.py
```

Manual CLI examples: [cli/video-to-60fps.md](../../../cli/video-to-60fps.md)
