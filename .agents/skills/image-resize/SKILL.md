---
name: image-resize
description: Resizes a single image to explicit width and height using ImageMagick. Use when the user wants image resize, scale a sprite/texture, resize a UI asset or icon, or mentions ImageMagick resize — target size must be specified before running.
---

# Image Resize

Resize **one image file** to a **user-specified width and height** via **ImageMagick**. **Both dimensions are required** — do not run this skill until the user (or task) provides target pixel size.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- **Require target size first.** If width/height are missing, ask the user before running.
- **Single file only.** Pass one image with `--image`; directories are not supported.
- Run `resize.py` through the bundled script — do not hand-write `magick -resize` commands.
- **Never overwrite source files.** Output goes to `image-resize/` (or `--output`) by default.
- `populated: false` for `imagemagick` is not a reason to skip. Install first, set `populated: true`, retry the same command.

## Setup (first run)

1. Download ImageMagick portable build from [imagemagick.org](https://imagemagick.org/script/download.php) and extract to `.dependency/imagemagick/`.

   Windows result example: `.dependency/imagemagick/magick.exe`

2. Register in `.dependency/manifest.json`:

```json
"imagemagick": {
  "populated": true,
  "bin": ".dependency/imagemagick/magick.exe"
}
```

Use `bin/magick` on Unix (no `.exe`).

## Quick Start

**Both `--width` and `--height` are required:**

```bash
.dependency/python/python .ai/image-resize/resize.py --image assets/sprites/hero.png --width 128 --height 128
```

Example: `assets/ui/icon.png` → `assets/ui/image-resize/icon.png` at 64×64

Custom output path:

```bash
.dependency/python/python .ai/image-resize/resize.py --image assets/icons/badge.png -o assets/icons_64 --width 64 --height 64
```

## Resize Modes

| Mode | Flag | Behavior |
|------|------|----------|
| `fit` *(default)* | `--mode fit` | Fit inside WxH, preserve aspect ratio (letterbox area unused) |
| `fill` | `--mode fill` | Cover WxH, center-crop overflow |
| `exact` | `--mode exact` | Force WxH, ignore aspect ratio |

```bash
# Fit within 128×128 (default — no distortion)
.dependency/python/python .ai/image-resize/resize.py --image assets/hero.png --width 128 --height 128

# Cover 128×128, crop center
.dependency/python/python .ai/image-resize/resize.py --image assets/hero.png --width 128 --height 128 --mode fill

# Stretch to exactly 128×128
.dependency/python/python .ai/image-resize/resize.py --image assets/hero.png --width 128 --height 128 --mode exact
```

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single supported image file |
| `--width` / `--height` | **Required** | Must be positive integers |
| `--mode` | `fit` | `fill` or `exact` when user needs crop or stretch |
| Output | `<source-dir>/image-resize/<source-name>` | Use `--output` for custom file or directory |
| Format | Same as source | Extension preserved (`.png`, `.jpg`, etc.) |

Supported inputs: `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## Agent Workflow

1. **Confirm size** — get explicit width and height from the user (e.g. "128×128", "64 wide and 64 tall"). Do not guess from context unless the user already stated dimensions.
2. **Pick mode** — default `fit`; use `fill` for square thumbnails from non-square art; use `exact` only when the user accepts distortion.
3. **One file per run** — resize one image, verify dimensions, then repeat for additional files if needed.
4. **Paths** — pass whatever image path the user gives; output lands in `image-resize/` next to that file by default.
5. **Revert** — delete output file or `git restore`; sources are never modified.

## Agent Notes

1. Use the bundled script, not hand-written ImageMagick commands.
2. Missing Python/ImageMagick → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with resized output** — tell the user where the output file is.
4. Need **format conversion only** (no resize) → [image-to-png](../image-to-png/SKILL.md).
5. Need **trim borders** after resize → [image-trim](../image-trim/SKILL.md).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `imagemagick` missing in manifest | Follow **Setup**; update manifest |
| Missing `--width` / `--height` | Ask user for target size; both flags are required |
| Directory passed to `--image` | Run once per file; this skill accepts image files only |
| Output larger/smaller than expected | Check `--mode` — `fit` preserves aspect inside the box |
| Distorted sprite | Switch from `exact` to `fit` or `fill` |
| Animated GIF | Only first frame is processed by default ImageMagick behavior |

## CLI

Copy-paste commands: [cli/image-resize.md](../../../cli/image-resize.md)
