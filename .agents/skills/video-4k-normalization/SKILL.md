---
name: video-4k-normalization
description: >-
  Normalizes a single video clip to unified 3840×2160 60FPS H.265 Main10 40Mbps
  + AAC 320kbps BT.709 SDR MP4 4K master (FFmpeg re-encode, HDR tone-mapped).
  Use before hard-cut merge when 4K (or near-4K) clips differ in color space,
  HDR/SDR, fps, or size. Triggers: video-4k-normalization, 4K normalization,
  video normalization, media conform, unify encode, color conform, tone map HDR, prepare
  for video-merge, mixed HDR/SDR.
disable-model-invocation: true
---

# Video 4K Normalization

Re-encode a clip to one **merge-safe 4K master** (same delivery specs as
`video-to-4k`, plus **unified BT.709 SDR color**):

| Spec | Value |
|------|-------|
| Resolution | 3840×2160 |
| Frame rate | 60 FPS |
| Video | H.265 Main10 (`libx265`, `yuv420p10le`) |
| Video bitrate | 40 Mbps |
| Audio | AAC 320 kbps |
| Color | **BT.709 / bt709 / tv** (HDR → tone-mapped SDR) |
| Container | MP4 (`.mp4`, `hvc1` tag) |

**Not** AI upscaling — use [`video-to-4k`](../video-to-4k/SKILL.md) first when
SD/HD needs Real-ESRGAN quality. This skill uses FFmpeg `scale` + encode only.

## Why

Hard-cut [`video-merge`](../video-merge/SKILL.md) is stream-copy. Mixed
**HDR (BT.2020 + PQ)** and **SDR (BT.709)** clips look fine alone, but after
concat the player often applies the first clip's HDR tags to later SDR →
oversaturated cuts. Normalization unifies pixels **and** color tags first.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `normalize.py` through **`.dependency/python/python`**. Never use host `python` / `ffmpeg`.
- **Never overwrite sources.** Outputs go under `video-4k-normalization/`.
- Use the bundled script — do not hand-write equivalent FFmpeg commands.
- **One file per run** — pass `--video` with a single file; repeat for each clip in a batch.

## Quick Start

```bash
.dependency/python/python .ai/video-4k-normalization/normalize.py --video path/to/clip.mp4
```

Example:

```
assets/shots/01.mp4   (HDR)
→ assets/shots/video-4k-normalization/01.mp4

assets/shots/10.mp4   (SDR)
→ assets/shots/video-4k-normalization/10.mp4
```

Then hard-cut merge the `video-4k-normalization/` folder:

```bash
.dependency/python/python .ai/video-merge/merge.py --folder path/to/clips/video-4k-normalization
```

## Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Target color | BT.709 SDR limited (`tv`) | HDR (PQ/HLG/BT.2020) → `hable` tone map |
| Scale | FFmpeg lanczos to 3840×2160 | No Video2X |
| FPS | Forced 60 | Frame dup/drop, not RIFE |

## Common Flags

`--video` · `-o` / `--output`

```bash
.dependency/python/python .ai/video-4k-normalization/normalize.py --video clip.mp4
.dependency/python/python .ai/video-4k-normalization/normalize.py --video clip.mp4 -o out/masters/clip.mp4
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script only.
2. Missing Python / FFmpeg → populate `.dependency/`, set `populated: true`, retry.
3. Tell the user `video-4k-normalization/` paths; they run `video-merge` on that folder when stitching.
4. For low-res quality upscale → `video-to-4k`, then optionally re-normalize if color still mixed.
5. Pipeline / filter details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-4k-normalization/test_normalize.py
```

Manual CLI examples: [cli/video-4k-normalization.md](../../../cli/video-4k-normalization.md)
