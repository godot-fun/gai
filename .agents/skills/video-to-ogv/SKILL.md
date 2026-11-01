---
name: video-to-ogv
description: Converts a single video file to OGV (Theora + Vorbis in Ogg container) using FFmpeg for Godot-ready playback assets. Exports FFV1+FLAC lossless MKV intermediate then encodes Theora q=10 OGV for maximum fidelity. Use when the user wants to convert video to OGV, transcode MP4/MKV/MOV/WebM to OGV, export a cutscene or UI video, or mentions Theora, libtheora, VideoStreamTheora, or Godot video import.
---

# Video to OGV

Convert a supported video file to **OGV** (Theora video + Vorbis audio in an Ogg container) via FFmpeg.

Lossy sources always go through a lossless intermediate first, then OGV — to minimize generation loss.

1. Export **FFV1 + FLAC** lossless MKV to `video-to-ogv/lossless/`
2. Encode **Theora q=10 + Vorbis q=10** OGV to `video-to-ogv/`

Only Theora encoding is lossy; the intermediate decode is bit-perfect.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Convert a single video file:

```bash
.dependency/python/python .ai/video-to-ogv/convert.py --video path/to/video.mp4
```

Example:

```
assets/video/intro.mp4
  → assets/video/video-to-ogv/lossless/intro.mkv   (FFV1+FLAC intermediate)
  → assets/video/video-to-ogv/intro.ogv            (final Godot asset)
```

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Pipeline | Lossless → OGV | Skipped when source is already lossless |
| Intermediate | FFV1 + FLAC (`.mkv`) | Written to `video-to-ogv/lossless/`; large but bit-perfect decode |
| Final container | OGG (`.ogv`) | Godot `VideoStreamTheora` format |
| Final video | Theora q=10 | Single-pass from lossless intermediate |
| Final audio | Vorbis q=10 | Preserves source sample rate and channels |
| Resolution / frame rate | Preserve source | Never downscaled by default |
| Existing Theora+Vorbis OGV | Stream copy | Bit-perfect when no overrides |

## Disk Usage

Lossless intermediates are **much larger** than source MP4s (720p ≈ 50–200 MB per 10 s clip). They are kept in `video-to-ogv/lossless/` for re-encoding. Delete manually when done, or pass **`--clean-lossless`** to remove after each successful OGV export.

## Common Flags

`--video` · `-o` / `--output` · `--lossless-dir` · `--clean-lossless` · `--standardize`

Custom output path:

```bash
.dependency/python/python .ai/video-to-ogv/convert.py --video path/to/video.mp4 --output path/to/out.ogv
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script, not hand-written `ffmpeg -i …` commands.
2. **Always run with no extra quality flags** — the script only supports the lossless MKV → OGV pipeline.
3. **Do not downscale or change frame rate** unless the user explicitly asks.
4. **Do not resample audio or change channel layout** unless the user explicitly asks — omit `--standardize`.
5. **Already Theora+Vorbis OGV?** Stream-copied by default (no generation loss).
6. Tell the user where `video-to-ogv/` outputs are; they swap assets manually when ready.
7. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
8. Need **48 kHz audio** → pass `--standardize`.
9. FFmpeg pipeline details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-to-ogv/test_convert.py
```

Manual CLI examples: [cli/video-to-ogv.md](../../../cli/video-to-ogv.md)
