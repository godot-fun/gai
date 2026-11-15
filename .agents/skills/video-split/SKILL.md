---
name: video-split
description: Splits a single video into two precisely timed MP4 segments using FFmpeg, defaulting to two equal-duration halves. Re-encodes as compatible H.264/AAC so the cut is not shifted to a nearby keyframe. Use when the user wants to split or divide a video in half, cut a video into two parts, split at a timestamp, or separate the first and second half of a clip.
---

# Video Split

Split one video into **part 1** (start to split point) and **part 2** (split point to end). Default to the exact temporal midpoint.

## Rules

Read and follow [dependency-manager](../dependency-manager.md). Run the bundled script as documented and install missing tools into `.dependency/`.

## Quick Start

```bash
.dependency/python/python .ai/video-split/split.py --video path/to/video.mp4
```

Outputs:

```text
video-split/video_part1.mp4
video-split/video_part2.mp4
```

## Split Point

Provide at most one:

| Flag | Meaning |
|------|---------|
| `-s` / `--split-at` | Time in seconds |
| `-p` / `--percent` | Percentage of total duration |
| none | Exact 50% midpoint |

```bash
.dependency/python/python .ai/video-split/split.py --video clip.mov --split-at 12.5
.dependency/python/python .ai/video-split/split.py --video clip.webm --percent 30
```

## Output

Encode both parts as H.264 CRF 18, preset medium, yuv420p, with AAC 192 kbps and faststart. Preserve source resolution and frame rate. Re-encoding provides frame-accurate cuts instead of keyframe-limited stream-copy cuts.

Use `-o` / `--output` to choose an output directory. Never overwrite or modify the source.

## Agent Notes

1. Use the bundled script, not handwritten FFmpeg commands.
2. When the user asks for two halves without a timestamp, use the default 50% split.
3. Do not use stream copy; it can move cuts to keyframes and produce unequal parts.
4. Reject split points at zero or at/after the video duration.
5. Tell the user both output paths.
6. If Python or FFmpeg is missing, populate `.dependency/` and retry.
7. See [reference.md](reference.md) for the exact FFmpeg pipeline and cut behavior.

## Tests

```bash
.dependency/python/python .ai/video-split/test_split.py
```

Manual examples: [cli/video-split.md](../../../cli/video-split.md)
