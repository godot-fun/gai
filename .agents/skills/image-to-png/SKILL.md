---
name: image-to-png
description: Converts image files to PNG using FFmpeg while preserving dimensions and alpha. Use when the user wants to convert images to PNG, transcode JPG/WebP/GIF/BMP/TIFF to PNG, export a game/UI texture as PNG, or mentions PNG conversion without background removal.
---

# Image to PNG

Convert a **single image file** to **lossless PNG** via FFmpeg. **Defaults preserve source quality** — dimensions unchanged, alpha channel kept when present.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `convert.py` through the bundled script — do not hand-write `ffmpeg -i …` commands.
- **Single file only.** Pass one image with `--image`; directories are not supported.
- **Never overwrite source files.** Output goes to `image-to-png/` (or `--output`) by default.
- **Do not resize or recompress** unless the user explicitly asks — omit quality/size overrides.
- `populated: false` for `ffmpeg` is not a reason to skip. Install first, set `populated: true`, retry the same command.

## Setup (first run)

1. Download FFmpeg and extract to `.dependency/ffmpeg/` (see dependency-manager).

   Windows result example: `.dependency/ffmpeg/bin/ffmpeg.exe`

2. Register in `.dependency/manifest.json`:

```json
"ffmpeg": {
  "populated": true,
  "bin": ".dependency/ffmpeg/bin/ffmpeg.exe"
}
```

Use `bin/ffmpeg` on Unix (no `.exe`).

## Quick Start

**Default: create an `image-to-png/` folder beside the input file** and write the PNG there:

```bash
# assets/ui/icon.webp → assets/ui/image-to-png/icon.png
.dependency/python/python .ai/image-to-png/convert.py --image assets/ui/icon.webp
```

Custom output path:

```bash
.dependency/python/python .ai/image-to-png/convert.py --image assets/ui/icon.webp -o assets/ui_png
```

Strip alpha (RGB output):

```bash
.dependency/python/python .ai/image-to-png/convert.py --image assets/sprites/hero.webp --strip-alpha
```

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Dimensions | Preserve source | No resize unless user asks separately |
| Alpha | Preserve | RGBA when source has transparency |
| Already PNG | Stream copy | Bit-perfect when `--strip-alpha` is off |
| Animated GIF | First frame | Multi-frame GIF export not supported |

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single supported image file |
| Output | `<image-dir>/image-to-png/<name>.png` | Use `-o` / `--output` for custom file or directory |
| `--strip-alpha` | off | Force RGB PNG without alpha |

Supported inputs: `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## Agent Workflow

1. **Paths** — Pass whatever image path the user gives. Output lands in `image-to-png/` next to that file by default.
2. **One file per run** — convert one image, verify the result, then repeat for additional files if needed.
3. **Already PNG?** Stream-copied by default (no generation loss) unless `--strip-alpha` is set.
4. **Revert** — delete output file or `git restore`; sources are never modified.

## Agent Notes

1. Use the bundled script, not hand-written FFmpeg commands.
2. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with converted output** — tell the user where the output file is.
4. Need **transparent cutouts** → use [image-remove-background](../image-remove-background/SKILL.md), not this skill.
5. Need **resize** after conversion → [image-resize](../image-resize/SKILL.md).
6. FFmpeg codec and probing details: [reference.md](reference.md)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `ffmpeg` missing in manifest | Follow **Setup**; update manifest |
| Directory passed to `--image` | Run once per file; this skill accepts image files only |
| Output already exists | Delete the existing output or choose a different `-o` path |
| Animated GIF | Only first frame is exported by default |
| Need RGB only | Add `--strip-alpha` |


## CLI

Copy-paste commands: [cli/image-to-png.md](../../../cli/image-to-png.md)

## Related

- Resize after conversion: [image-resize](../image-resize/SKILL.md)
- Transparent cutouts: [image-remove-background](../image-remove-background/SKILL.md)
