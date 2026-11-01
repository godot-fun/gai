---
name: video-compress-to-size
description: Compresses a single video file to stay under a user-specified max file size using FFmpeg. Prefers GPU encoders (NVENC / AMF / QSV) with VBR bitrate targeting; falls back to CPU two-pass H.264/HEVC. Use when the user wants to compress video, reduce video file size, shrink MP4/MKV/MOV under N MB, GPU encode, NVENC compress, or re-encode a clip to a size limit.
---

# Video Compress To Size

Re-encode a supported video so the output is **at or under** a given max file size.

**Default:** probe and use a GPU encoder when available (NVIDIA NVENC → AMD AMF → Intel QSV), single-pass VBR. If no GPU works, fall back to **CPU two-pass** (`libx264` / `libx265`).

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `compress.py` through **`.dependency/python/python.exe`**. Never use host `python` / `ffmpeg`.
- **Never overwrite sources.** Outputs go under `video-compress-to-size/`.
- Use the bundled script — do not hand-write equivalent FFmpeg commands.
- **One file per run** — pass `--video` with a single file; repeat for each clip in a batch.

## Quick Start

```bash
.dependency/python/python .ai/video-compress-to-size/compress.py --video path/to/clip.mp4 --max-size 50MB
```

Bare numbers mean **MB** (`--max-size 50` ≡ `50MB`):

```bash
.dependency/python/python .ai/video-compress-to-size/compress.py --video assets/intro.mp4 --max-size 50
```

Example:

```
assets/video/intro.mp4
  → assets/video/video-compress-to-size/intro.mp4
```

Force CPU (slow, more precise two-pass):

```bash
.dependency/python/python .ai/video-compress-to-size/compress.py --video clip.mp4 --max-size 50MB --cpu
```

## Size Syntax

| Input | Meaning |
|-------|---------|
| `50` / `50MB` / `50M` | 50 mebibytes (1024² bytes) |
| `500KB` / `500K` | 500 kibibytes |
| `1GB` / `1G` | 1 gibibyte |
| `52428800B` | exact bytes |

`--max-size` is **required**.

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Encoder | GPU first | `h264_nvenc` → `h264_amf` → `h264_qsv` → `libx264` |
| HEVC | `--hevc` | Same order with `hevc_*` / `libx265` |
| Container | `.mp4` | Always MP4 |
| Audio | AAC 128k | Lowered automatically on tiny budgets |
| Preset | `medium` | Mapped (e.g. NVENC `p4`); override with `--preset` |
| Already under limit | Skipped | `[skip] … (already under limit)` |
| Safety margin | GPU ~90% / CPU ~92% | Headroom for mux / VBR overshoot |

## Common Flags

`--video` · `--max-size` · `-o` / `--output` · `--audio-bitrate` · `--preset` · `--hevc` · `--cpu`

Custom output path:

```bash
.dependency/python/python .ai/video-compress-to-size/compress.py --video clip.mp4 --max-size 50MB -o out/clip.mp4
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script, not hand-written `ffmpeg` commands.
2. Always pass `--max-size` from the user (ask if missing). Prefer their unit wording; bare numbers are MB.
3. **Prefer GPU** — do not pass `--cpu` unless the user asks or GPU encode fails.
4. Do **not** downscale or change fps unless the user asks.
5. Sources already ≤ max size are skipped.
6. Tell the user where `video-compress-to-size/` files are; they swap assets manually when ready.
7. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
8. Pipeline details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-compress-to-size/test_compress.py
```

Manual CLI examples: [cli/video-compress-to-size.md](../../../cli/video-compress-to-size.md)
