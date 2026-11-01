---
name: image-remove-background
description: >-
  Removes image backgrounds and exports transparent PNGs using rembg (U2Net / BiRefNet).
  Use when the user wants background removal, matting, cutout, background cutout, transparent sprites,
  alpha PNG export, or remove background from a game/UI asset.
---

# Image Remove Background (rembg)

Remove image backgrounds with AI matting via **rembg**. Output is **RGBA PNG** with transparent background — ready for Godot sprites and UI.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `remove_background.py` through the **`rembg` manifest entry** (`.dependency/rembg/.venv/`). Never use host `python`, `py`, `python3`, or any interpreter outside `.dependency/`.
- Do not hand-write `rembg i` / `rembg p` — use the bundled script.
- **Single file only.** Pass one image with `--image`; directories are not supported.
- `populated: false` for `rembg` is not a reason to skip. Install first, set `populated: true`, retry the same command.
- Pass the input path as-is (chat attachment path, `Downloads/foo.png`, project folder, etc.). Output goes to `<image-dir>/image-remove-background/` by default — no path rewriting.
- **Never overwrite source files.** Output lands in `image-remove-background/` or `--output`.

## Setup (first run)

From project root:

```bash
.dependency/python/python -m venv .dependency/rembg/.venv
.dependency/rembg/.venv/Scripts/python.exe -m pip install "rembg[cpu]"
```

GPU (CUDA) — faster processing:

```bash
.dependency/rembg/.venv/Scripts/python.exe -m pip install "rembg[gpu]"
```

Register in `.dependency/manifest.json`:

```json
"rembg": {
  "populated": true,
  "bin": ".dependency/rembg/.venv/Scripts/python.exe"
}
```

Use `bin/python` on Unix. Model weights download on first run (~hundreds of MB).

## Quick Start

**Default: create an `image-remove-background/` folder beside the input file** and write the PNG there (never overwrites sources):

```bash
# image/sprites/hero.png → image/sprites/image-remove-background/hero.png
.dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/sprites/hero.png
```

Custom output path:

```bash
.dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/sprites/hero.png -o image/sprites/hero_cutout
```

## Model selection

| Model | Use case |
|-------|----------|
| `u2net` *(default)* | General objects, icons, props |
| `u2netp` | Faster / lighter; smaller assets |
| `isnet-general-use` | Higher quality general matting |
| `birefnet-general` | Best general quality (slower) |
| `birefnet-portrait` | Characters / portraits |
| `u2net_human_seg` | Human figures only |

```bash
.dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/character.png --model birefnet-portrait
```

## Edge quality (alpha matting)

For hair, fur, or soft edges, enable alpha matting:

```bash
.dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/portrait.png --alpha-matting
```

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single supported image file |
| Output | `<image-dir>/image-remove-background/<name>.png` | Use `-o` / `--output` for custom file or directory |
| `--model` | `u2net` | See table above |
| `--alpha-matting` | off | Enable for fine edge detail |
| `--crop` | off | Trim transparent borders after matting |

Supported inputs: `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## Agent Workflow

1. **Paths** — Pass whatever image path the user gives or the chat `<image_files>` path directly. Output lands in `image-remove-background/` next to that file by default.
2. **One file per run** — process one image, verify the result, then repeat for additional files if needed.
3. **Pick model** — `u2net` for generic assets; `birefnet-portrait` for characters; `birefnet-general` when quality matters.
4. **Soft edges** — try `--alpha-matting` if halos or jagged hair/fur appear.
5. **Already transparent** — script still runs; rembg re-mats from visible RGB. Warn user if source already has alpha.
6. **Revert** — delete output file or `git restore` if needed; sources are never modified.

## Agent Notes

1. Use the bundled script, not hand-written `rembg` CLI commands.
2. Missing rembg venv → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with cutout output** — tell the user where the output file is.
4. Flat white/green/magenta AI backgrounds → prefer [image-remove-white-background](../image-remove-white-background/SKILL.md) over rembg.
5. Need **trim borders** after matting → [image-trim](../image-trim/SKILL.md).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `rembg` missing | Follow **Setup**; update manifest |
| Directory passed to `--image` | Run once per file; this skill accepts image files only |
| Output already exists | Delete the existing output or choose a different `-o` path |
| Very slow | Install `rembg[gpu]`; try `--model u2netp` |
| Jagged edges | `--alpha-matting` |
| Wrong subject removed | Switch model; try `birefnet-general` |
| Leftover background color | Re-run with `--alpha-matting`; check source contrast |
| OOM on large images | Script auto-downscales inputs above 4096 px longest side |


## CLI

Copy-paste commands: [cli/image-remove-background.md](../../../cli/image-remove-background.md)

## Related

- Flat white/green/magenta AI backgrounds: [image-remove-white-background](../image-remove-white-background/SKILL.md) (prefer over rembg)
- rembg docs: https://github.com/danielgatis/rembg
