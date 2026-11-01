---
name: image-trim
description: >-
  Trims invalid border regions (transparent or solid-color padding) from images
  using Pillow. Default crop preserves the source aspect ratio. Use when the user
  wants image trim, crop empty borders, remove transparent margins, trim white
  padding, auto-crop sprites, or tighten cutouts before Godot import.
---

# Image Trim

Remove **invalid border padding** — transparent margins, flat white/green edges, or unused canvas space — with **Pillow**. **Default: preserve the source aspect ratio** so trimmed sprites stay proportionally consistent with the original frame.

Unlike `--crop` on [image-remove-white-background](../image-remove-white-background/SKILL.md) (tight alpha bbox only), this skill expands the crop box to match the original width:height ratio while removing as much empty area as possible.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `trim.py` through the **`image-trim` manifest entry** (`.dependency/image-trim/.venv/`). Never use host `python`, `py`, `python3`, or any interpreter outside `.dependency/`.
- Do not hand-write ImageMagick / FFmpeg crop commands — use the bundled script.
- **Single file only.** Pass one image with `--image`; directories are not supported.
- `populated: false` for `image-trim` is not a reason to skip. Install first, set `populated: true`, retry the same command.
- Pass the input path as-is. Output goes to `<image-dir>/image-trim/` by default — no path rewriting; **never overwrite sources**.
- **Crop only** — preserve source pixel data and alpha; never composite onto black/white or fill background colors.
- Output filenames keep the **original asset name** (e.g. `bullet_speed.png`). Cursor chat attachment paths like `empty-window_images_bullet_speed-<uuid>.png` are shortened automatically.

## Setup (first run)

From project root:

```bash
.dependency/python/python -m venv .dependency/image-trim/.venv
.dependency/image-trim/.venv/Scripts/python.exe -m pip install Pillow
```

Register in `.dependency/manifest.json`:

```json
"image-trim": {
  "populated": true,
  "bin": ".dependency/image-trim/.venv/Scripts/python.exe"
}
```

Use `bin/python` on Unix.

## Quick Start

**Default: create an `image-trim/` folder beside the input file** and write the output there:

```bash
# Auto-detect transparent or solid-color borders (default)
# image/sprites/hero.png → image/sprites/image-trim/hero.png
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/sprites/hero.png
```

Custom output path:

```bash
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/sprites/hero.png -o image/sprites_trimmed
```

## Detection Modes

| Mode | Behavior |
|------|----------|
| `auto` *(default)* | Use alpha when the image has transparency; otherwise sample corner color and trim solid borders |
| `alpha` | Trim only by alpha — pixels above `--alpha-threshold` count as content |
| `color` | Trim pixels matching `--color` (or corner sample) within `--tolerance` |

```bash
# Force alpha-only trim on RGBA cutouts
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/cutout.png --mode alpha

# Trim white padding on opaque JPG/PNG
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/foo.jpg --mode color --color FFFFFF
```

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single supported image file |
| Output | `<image-dir>/image-trim/<name>` | Use `-o` / `--output` for custom file or directory |
| Aspect ratio | **Preserve source** | Pass `--tight` for tight bbox crop (no aspect lock) |
| `--mode` | `auto` | `alpha` for transparent PNGs; `color` for flat backgrounds |
| `--alpha-threshold` | `10` | Lower = stricter transparency detection |
| `--tolerance` | `25` | Color distance for solid-border trim |
| `--padding` | `0` | Extra pixels kept around detected content |

Supported inputs: `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## Aspect Ratio Behavior

**Default (preserve source):** After detecting the content bounding box, the script expands the crop rectangle to the **same width:height ratio as the source image**, centered on the content. This removes empty borders while keeping frame proportions stable for animation sheets and UI assets.

**Tight crop (`--tight`):** Crop exactly to the content bbox (plus `--padding`) — same behavior as `--crop` on background-removal skills.

```bash
# Tight crop — smallest rectangle around content
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/sprites/hero.png --tight

# Keep 4 px breathing room, still preserve aspect ratio
.dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/sprites/hero.png --padding 4
```

## Agent Workflow

1. **Pick skill** — remove padding/margins → this skill; remove backgrounds → [image-remove-white-background](../image-remove-white-background/SKILL.md) or [image-remove-background](../image-remove-background/SKILL.md).
2. **Paths** — Pass whatever image path the user gives. Output lands in `image-trim/` next to that file by default.
3. **One file per run** — trim one image, verify dimensions, then repeat for additional files if needed.
4. **After background removal** — run on `image-remove-background/` outputs to drop excess transparent canvas.
5. **Revert** — delete output file or `git restore`; sources are never modified.

## Agent Notes

1. Use the bundled script, not hand-written ImageMagick / FFmpeg crop commands.
2. Missing image-trim venv → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with trimmed output** — tell the user where the output file is.
4. Need **background removal** first → [image-remove-white-background](../image-remove-white-background/SKILL.md) or [image-remove-background](../image-remove-background/SKILL.md).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `image-trim` missing in manifest | Follow **Setup**; update manifest |
| Directory passed to `--image` | Run once per file; this skill accepts image files only |
| Output already exists | Delete the existing output or choose a different `-o` path |
| Nothing trimmed | Content may already fill the canvas; try `--mode color` with `--color` |
| Too much removed | Lower `--tolerance` or `--alpha-threshold`; add `--padding` |
| Borders remain | Raise `--tolerance`; use `--mode color` with explicit `--color` |
| Distorted proportions after trim | Do **not** pass `--tight` unless user wants tight bbox |
| JPEG saved with wrong mode | Script converts RGBA → RGB automatically for `.jpg` output |
| Output has black instead of transparency | Source may be JPEG data saved with a `.png` extension (Cursor attachments) — re-supply the original RGBA PNG |
| Long Cursor attachment filenames | Script auto-renames to the embedded asset name (`bullet_speed.png`, etc.) |


## CLI

Copy-paste commands: [cli/image-trim.md](../../../cli/image-trim.md)

## Related

- Background removal: [image-remove-white-background](../image-remove-white-background/SKILL.md), [image-remove-background](../image-remove-background/SKILL.md)
- Resize after trim: [image-resize](../image-resize/SKILL.md)
