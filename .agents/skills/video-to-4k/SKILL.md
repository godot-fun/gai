---
name: video-to-4k
description: >-
  Upscales a single low-resolution video to 4K with Video2X (Real-ESRGAN), then
  encodes to unified 3840×2160 H.265 Main10 40Mbps + AAC 320kbps MP4. Source frame
  rate is preserved (no fps=60 duplication, no RIFE). Already-4K sources skip
  Video2X and go straight to FFmpeg. Use when the user wants video-to-4k, 4K
  upscale, UHD export, Video2X, Real-ESRGAN, H.265 Main10, or convert an SD/HD
  clip to 4K.
---

# Video to 4K

Convert a supported video to a **unified 4K master**:

| Spec | Value |
|------|-------|
| Resolution | 3840×2160 |
| Frame rate | **Source fps kept** (no `fps=` filter, no RIFE) |
| Video | H.265 Main10 (`libx265`, `yuv420p10le`) |
| Video bitrate | 40 Mbps |
| Audio | AAC 320 kbps |
| Container | MP4 (`.mp4`, `hvc1` tag) |

## Pipeline

1. **Probe** with ffprobe (width, height, fps, audio).
2. **Already 4K?** (`width ≥ 3840` and `height ≥ 2160`) → skip Video2X.
3. **Below 4K** → [Video2X](https://github.com/k4yt3x/video2x) Real-ESRGAN upscale (scale 2 or 4) to intermediate under `video-to-4k/upscaled/`.
4. **Always** FFmpeg final encode → `video-to-4k/` at the unified specs above.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `convert.py` through **`.dependency/python/python`**. Never use host `python` / `ffmpeg` / `video2x`.
- **Never overwrite sources.** Outputs go under `video-to-4k/` (final) and `video-to-4k/upscaled/` (Video2X intermediate).
- Use the bundled script — do not hand-write equivalent `video2x` / `ffmpeg` commands.
- **One file per run** — pass `--video` with a single file; repeat for each clip in a batch.

## Setup (first run)

### FFmpeg + Python

Populate `ffmpeg` and `python` under `.dependency/` per dependency-manager.

### Video2X (CLI)

Download the **CLI** release (not the Qt6 installer) from [video2x releases](https://github.com/k4yt3x/video2x/releases/latest) and extract to `.dependency/video2x/`:

| Platform | Release asset |
|----------|---------------|
| Windows | `video2x-windows-amd64.zip` → `video2x.exe` |
| Linux | `Video2X-x86_64.AppImage` (or distro package) → register as `bin` |

Register in `.dependency/manifest.json`:

```json
"video2x": {
  "populated": true,
  "bin": ".dependency/video2x/video2x.exe"
}
```

Use `video2x` (no `.exe`) or the AppImage path on Unix. Requires a **Vulkan** GPU and AVX2 CPU. Docs: [Command Line](https://docs.video2x.org/running/command-line.html).

## Quick Start

```bash
.dependency/python/python .ai/video-to-4k/convert.py --video path/to/clip.mp4
```

Example:

```
assets/video/clip.mp4
  → assets/video/video-to-4k/upscaled/clip.mkv   (Video2X, only if below 4K)
  → assets/video/video-to-4k/clip.mp4            (final master)
```

Already-4K source → only `video-to-4k/clip.mp4` (FFmpeg only).

Anime / cartoon content (Real-ESRGAN anime model):

```bash
.dependency/python/python .ai/video-to-4k/convert.py --video clip.mp4 --anime
```

## Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Upscaler | Real-ESRGAN `realesrgan-plus` | General / live-action |
| `--anime` | `realesr-animevideov3` | Anime / illustration |
| Scale | Auto 2 or 4 | Smallest factor that meets or exceeds 4K |
| Intermediate | High-bitrate HEVC MKV in `video-to-4k/upscaled/` | Kept for re-encode; delete manually or `--clean-upscaled` |
| Final | Always re-encode | Even if source already matches specs |

## Common Flags

`--video` · `-o` / `--output` · `--anime` · `--gpu` · `--clean-upscaled`

```bash
.dependency/python/python .ai/video-to-4k/convert.py --video clip.mp4
.dependency/python/python .ai/video-to-4k/convert.py --video clip.mp4 --gpu 0 --clean-upscaled
.dependency/python/python .ai/video-to-4k/convert.py --video clip.mp4 -o out/clip.mp4
```

**Never overwrite source files.** Input must be a single video file (`--video`), not a directory. Supported inputs: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script only.
2. Missing Python / FFmpeg / Video2X → populate `.dependency/`, set `populated: true`, retry the same command.
3. Tell the user where `video-to-4k/` (and `video-to-4k/upscaled/` if used) outputs are; they swap assets manually.
4. Default model is **general** (`realesrgan-plus`). Pass `--anime` for anime/cartoon.
5. Do **not** force fps. Keep the source frame rate. Need 60fps interpolation → **video-to-60fps** first (RIFE at source resolution).
6. Pipeline / FFmpeg / Video2X details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-to-4k/test_convert.py
```

Manual CLI examples: [cli/video-to-4k.md](../../../cli/video-to-4k.md)
