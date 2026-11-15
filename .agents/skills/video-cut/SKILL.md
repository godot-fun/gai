---
name: video-cut
description: Cuts a single video at a specified time into two precisely timed MP4 segments using FFmpeg, defaulting to two equal-duration halves when no time is given. Re-encodes as compatible H.264/AAC so the cut is not shifted to a nearby keyframe. Use when the user wants to cut or divide a video into two parts, cut at a timestamp, split a video in half, or separate the first and second portions of a clip.
---

# Video Cut

Split one video into **part 1** (start to split point) and **part 2** (split point to end). Default to the exact temporal midpoint.

## Rules

Read and follow [dependency-manager](../dependency-manager.md). Run the bundled script as documented and install missing tools into `.dependency/`.

## Quick Start

```bash
.dependency/python/python .ai/video-cut/cut.py --video path/to/video.mp4
```

Outputs:

```text
video-cut/video_part1.mp4
video-cut/video_part2.mp4
```

## Cut Point

Use one optional parameter:

| Flag | Meaning |
|------|---------|
| `-s` / `--seconds` | Cut position in seconds |
| none | Exact 50% midpoint |

```bash
.dependency/python/python .ai/video-cut/cut.py --video clip.mov --seconds 12.5
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
.dependency/python/python .ai/video-cut/test_cut.py
```

Manual examples: [cli/video-cut.md](../../../cli/video-cut.md)
