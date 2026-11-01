---
name: video-remove-audio
description: Removes all audio and music tracks from a single video file using FFmpeg, keeping the video stream (stream copy by default). Use when the user wants to mute a video, strip audio, remove soundtrack/BGM/music from MP4/MKV/MOV/WebM, export silent video, or remove audio from a cutscene clip.
---

# Video Remove Audio

Strip **all audio tracks** (music, voice, SFX) from a supported video file via FFmpeg. **Defaults preserve the video bitstream** — stream-copy video (`-c:v copy`), drop audio (`-an`), no re-encode.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `remove_audio.py` through **`.dependency/python/python.exe`**. Never use host `python` / `ffmpeg`.
- **Never overwrite sources.** Outputs go under `video-remove-audio/`.
- Use the bundled script — do not hand-write equivalent FFmpeg commands.
- **One file per run** — pass `--video` with a single file; repeat for each clip in a batch.

## Quick Start

```bash
.dependency/python/python .ai/video-remove-audio/remove_audio.py --video path/to/clip.mp4
```

Example:

```
assets/intro.mp4
  → assets/video-remove-audio/intro.mp4
```

Same video codec/container, no audio.

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Video | Stream copy | No quality loss; same codec/resolution/fps |
| Audio | Removed (`-an`) | Drops every audio stream |
| Container | Same as source | Extension preserved |
| Already silent | Skipped | Reports `[skip]` when no audio streams |

## Common Flags

`--video` · `-o` / `--output`

```bash
.dependency/python/python .ai/video-remove-audio/remove_audio.py --video clip.mp4
.dependency/python/python .ai/video-remove-audio/remove_audio.py --video clip.mp4 -o out/silent.mp4
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script, not hand-written `ffmpeg -i … -an` commands.
2. Always uses **stream copy** for video (`-c:v copy -an`).
3. This removes **all** audio; it does **not** isolate or mute music while keeping dialogue (no stem separation).
4. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
5. **Do not copy, move, or replace the source with muted output** — tell the user where `video-remove-audio/` files are; they swap assets manually when ready.
6. Need audio extracted instead of removed → use **video-to-wav**.
7. FFmpeg details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-remove-audio/test_remove_audio.py
```

Manual CLI examples: [cli/video-remove-audio.md](../../../cli/video-remove-audio.md)
