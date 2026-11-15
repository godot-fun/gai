---
name: video-to-mp4
description: Converts a single video file to a broadly compatible MP4 using FFmpeg (H.264 video, AAC audio, yuv420p, and faststart), while preserving source resolution and frame rate. Stream-copies an already compatible H.264/AAC MP4 to avoid generation loss. Use when the user wants to convert MKV/MOV/WebM/AVI/OGV or another video to MP4, transcode a video for browser/device compatibility, or mentions H.264, AAC, libx264, faststart, or MP4 export.
---

# Video to MP4

Convert one supported video file to a broadly compatible MP4 via FFmpeg.

- Encode video as **H.264 (libx264), CRF 18, preset slow, yuv420p**.
- Encode audio as **AAC 192 kbps**.
- Preserve source resolution, frame rate, audio sample rate, and channel layout.
- Add **faststart** metadata for web playback.
- Stream-copy an already compatible H.264/AAC MP4.

## Rules

Read and follow [dependency-manager](../dependency-manager.md). Run the bundled script as documented and install missing tools into `.dependency/`.

## Quick Start

```bash
.dependency/python/python .ai/video-to-mp4/convert.py --video path/to/video.mkv
```

Default output:

```text
assets/video/intro.mkv
  -> assets/video/video-to-mp4/intro.mp4
```

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Container | MP4 | `+faststart` enabled |
| Video | H.264 / libx264 | CRF 18, preset slow, high profile |
| Pixel format | yuv420p | Broad hardware/browser compatibility |
| Audio | AAC 192 kbps | Source rate and channels preserved |
| Resolution / frame rate | Preserve source | No scaling or FPS conversion |
| Compatible H.264/AAC MP4 | Stream copy | No generation loss |

## Common Flags

`--video` · `-o` / `--output` · `--crf` · `--preset` · `--audio-bitrate` · `--force-encode`

```bash
.dependency/python/python .ai/video-to-mp4/convert.py --video path/to/video.webm --output path/to/out.mp4
.dependency/python/python .ai/video-to-mp4/convert.py --video path/to/video.mov --crf 20 --preset medium
```

Never overwrite the source. Input must be one video file, not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script instead of writing an ad-hoc FFmpeg command.
2. Keep the default quality and compatibility settings unless the user explicitly asks otherwise.
3. Do not resize or change frame rate.
4. Use `--force-encode` only when the user explicitly wants re-encoding of an already compatible MP4.
5. Tell the user where the `video-to-mp4/` output was written; do not replace the source.
6. If Python or FFmpeg is missing, populate `.dependency/` per dependency-manager and retry.
7. See [reference.md](reference.md) for the exact FFmpeg pipelines.

## Tests

```bash
.dependency/python/python .ai/video-to-mp4/test_convert.py
```

Manual examples: [cli/video-to-mp4.md](../../../cli/video-to-mp4.md)
