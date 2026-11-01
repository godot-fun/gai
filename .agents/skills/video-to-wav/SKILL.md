---
name: video-to-wav
description: Extracts audio tracks from a single video file to PCM WAV using FFmpeg while preserving source quality. Use when the user wants to extract audio from video, rip sound from MP4/MKV/MOV/WebM, or export video audio to WAV without quality loss.
---

# Video to WAV

Extract the first audio track from a supported video file to **PCM WAV** via FFmpeg. **Defaults preserve source quality** — no resampling, bit depth matched from the embedded audio (32-bit float for lossy codecs), channels preserved, video stream discarded (`-vn`).

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default output: `<video-dir>/video-to-wav/<basename>.wav`

```bash
.dependency/python/python .ai/video-to-wav/convert.py --video path/to/video.mp4
```

Example: `assets/clip.mp4` → `assets/video-to-wav/clip.wav` (same rate/depth as embedded audio)

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Audio track | First (`a:0`) | Use `--track N` for alternate tracks (0-based) |
| Sample rate | Preserve source | Always kept; use `audio-sample-rate-standardize` to resample |
| Bit depth | Match source | Probed per file; lossy → 32-bit float PCM |
| Channels | Preserve source | Always kept from embedded audio |
| Lossless PCM in container | Stream copy | Bit-perfect when no overrides |

## Common Flags

`--video` · `-o` / `--output` · `--track` · `-b` / `--bit-depth`

Alternate audio track:

```bash
.dependency/python/python .ai/video-to-wav/convert.py --video clip.mkv --track 1
```

Custom output path:

```bash
.dependency/python/python .ai/video-to-wav/convert.py --video clip.mp4 --output path/to/out.wav
```

**Never overwrite source files.** The script writes only under `video-to-wav/` (or `--output`). Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`.

## Agent Notes

1. Use the bundled script, not hand-written `ffmpeg -i …` commands.
2. **Sample rate is always preserved** — chain `audio-sample-rate-standardize` if resampling is needed.
3. **Do not reduce bit depth** unless the user explicitly asks — omit `-b`.
4. **No audio track** — script reports failure; confirm the file has an audio stream.
5. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
6. **Do not copy, move, or replace the source with extracted output** — tell the user where output files are; they swap assets manually when ready.
7. This skill is for video containers only; standalone audio files are out of scope.
8. FFmpeg codec and probing details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-to-wav/test_convert.py
```

Manual CLI examples: [cli/video-to-wav.md](../../../cli/video-to-wav.md)
