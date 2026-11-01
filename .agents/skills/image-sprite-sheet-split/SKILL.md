---
name: image-sprite-sheet-split
description: Splits uniform sprite sheet grids into individual frame PNGs using FFmpeg crop. Use when the user wants to split sprite sheets, extract animation frames, divide grid images into cells, cut 4x4 or NxM sheets, slice tilesets, or prepare frames for background removal.
---

# Image Sprite Sheet Split

Split **uniform grid sprite sheets** into individual **PNG frames** via FFmpeg crop. Preserves per-cell dimensions and alpha. Does **not** remove backgrounds — run [image-remove-background](../image-remove-background/SKILL.md) on frames afterward if needed.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `split_frames.py` through the **`python` manifest entry** (`.dependency/python/`). Never use host `python`, `py`, or `python3`.
- Do not hand-write FFmpeg crop commands — use the bundled script.
- **Single file only.** Pass one sprite sheet with `--image`; directories are not supported.
- **Grid size required.** Supply `--grid COLSxROWS` before running (e.g. `4x4`, `6x3`).
- `populated: false` is not a reason to skip. Install first, set `populated: true`, retry the same command.
- **Never overwrite sources.** Output goes into `<image-dir>/image-sprite-sheet-split/<sheet-stem>/` by default (or under `-o`).
- **Never copy or move input images.** Pass the user's actual file path.

## Setup (first run)

1. Ensure `python` and `ffmpeg` are populated in `.dependency/manifest.json` (see dependency-manager).

2. FFmpeg must include `ffprobe` beside `ffmpeg` in the same `bin/` folder.

## Quick Start

**Default: `<image-dir>/image-sprite-sheet-split/<sheet-stem>/`** beside the input sheet:

```bash
# 4×4 sheet → image/effects/image-sprite-sheet-split/fire_sheet/fire_sheet_001.png … fire_sheet_016.png
.dependency/python/python .ai/image-sprite-sheet-split/split_frames.py --image image/effects/fire_sheet.png --grid 4x4
```

Custom output root:

```bash
.dependency/python/python .ai/image-sprite-sheet-split/split_frames.py --image image/effects/fire_sheet.png --grid 4x4 -o image/effects/frames/
# → image/effects/frames/fire_sheet/fire_sheet_001.png …
```

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single sprite sheet image file |
| `--grid` | **Required** | **COLSxROWS** (columns first), e.g. `4x4`, `6x3` |
| Output | `image-sprite-sheet-split/<stem>/` | Use `-o` / `--output` for a custom root directory |

Frames are exported **row-major** (left→right, top→bottom): `_001`, `_002`, …

Supported inputs: `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## When to use

| Good fit | Poor fit |
|----------|----------|
| Uniform N×M grid (4×4, 3×6, 8×1) | Irregular / free-form layouts |
| Gemini or Aseprite-style sheets | Packed texture atlases with variable frame sizes |
| Sheets without gutters or border padding | Sheets with grid lines, gutters, or outer padding |
| Preparing frames for per-frame background removal | Auto-detecting grid size (must be supplied) |

**rembg on whole sheets removes animation content** — split frames first, then remove backgrounds per frame if needed.

## Agent Workflow

1. **Confirm grid size** — ask or infer from context (`4x4`, `3x6`, etc.).
2. **Trial first** — split one sheet, inspect `image-sprite-sheet-split/<stem>/001.png` and the last frame.
3. **Check warnings** — if image size is not evenly divisible, verify cell crops still look correct.
4. **More sheets** — run once per file with the same grid settings.
5. **Revert** — delete the output folder; sources are never modified.

## Examples

4×4 explosion sheet (2048×2048 → 16 × 512×512):

```bash
.dependency/python/python .ai/image-sprite-sheet-split/split_frames.py --image sheet.png --grid 4x4
```

6×3 sheet:

```bash
.dependency/python/python .ai/image-sprite-sheet-split/split_frames.py --image sheet.png --grid 6x3
```

## Agent Notes

1. Use the bundled script, not hand-written FFmpeg crop commands.
2. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with frame outputs** — tell the user where the output folder is.
4. Need **transparent frames** → split first, then [image-remove-background](../image-remove-background/SKILL.md) on each frame.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `FFmpeg not found` | Populate `ffmpeg` in `.dependency/manifest.json` |
| Directory passed to `--image` | Run once per sheet; this skill accepts image files only |
| Output already exists | Delete the existing frame folder or choose a different `-o` path |
| Wrong frame count | Verify `--grid` matches the sheet layout |
| Misaligned crops | Sheet may have gutters/padding — this skill expects a clean uniform grid |
| Unused pixels warning | Image size is not evenly divisible by the grid; inspect output frames |
| Need transparent frames | Split first, then [image-remove-background](../image-remove-background/SKILL.md) on frames |


## CLI

Copy-paste commands: [cli/image-sprite-sheet-split.md](../../../cli/image-sprite-sheet-split.md)

## Related

- Transparent cutouts per frame: [image-remove-background](../image-remove-background/SKILL.md)
- Trim frame borders: [image-trim](../image-trim/SKILL.md)
