---
name: image-inpaint-region
description: >-
  Local circular region inpainting with LaMa (IOPaint). Uses IOPaint default
  InpaintRequest and mask handling. Use for local region inpaint / local region repair / inpaint when
  circle center and radius cx,cy,r are known.
---

# Image Inpaint Region (LaMa)

**Local circular region inpainting** with **[IOPaint](https://github.com/Sanster/IOPaint) LaMa**. Builds a circular mask from `--region cx,cy,r`, then runs the same inference path as `iopaint run` / the IOPaint API.

**Both `--image` and `--region cx,cy,r` are required.**

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `inpaint.py` through the **`iopaint` manifest entry** (`.dependency/iopaint/.venv/`). Never use host `python`, `py`, `python3`, or any interpreter outside `.dependency/`.
- Do not hand-write equivalent inpaint commands — use the bundled script.
- **Single file only.** Pass one image with `--image`; directories are not supported.
- **Require region first.** If `--region cx,cy,r` is missing, inspect the image (or ask the user) before running.
- **Use IOPaint defaults** for inference config unless the user explicitly asks otherwise — do not invent custom mask blur, compositing, or hd_strategy overrides in the script.
- Pass the input path as-is. Output goes to `<image-dir>/image-inpaint-region/` by default — no path rewriting.
- **Never overwrite source files.** Output lands in `image-inpaint-region/` or `--output`.

## Setup (first run)

IOPaint needs **Python 3.11** and PyTorch. From project root:

```bash
.dependency/python-3.11/python.exe -m venv .dependency/iopaint/.venv
.dependency/iopaint/.venv/Scripts/python.exe -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
.dependency/iopaint/.venv/Scripts/python.exe -m pip install iopaint
```

CPU-only: skip the CUDA torch line and `pip install iopaint` (pulls CPU torch). Use `bin/python` on Unix.

Register in `.dependency/manifest.json`:

```json
"iopaint": {
  "populated": true,
  "bin": ".dependency/iopaint/.venv/Scripts/python.exe"
}
```

LaMa weights (`big-lama.pt`) download on first run.

## Quick Start

**Both `--image` and `--region` are required:**

```bash
# image/foo.png → image/image-inpaint-region/foo.png
# center (148, 248), radius 48
.dependency/iopaint/.venv/Scripts/python.exe .ai/image-inpaint-region/inpaint.py --image image/foo.png --region 148,248,48
```

GPU inference:

```bash
.dependency/iopaint/.venv/Scripts/python.exe .ai/image-inpaint-region/inpaint.py --image image/foo.png --region 148,248,48 --device cuda
```

Custom output path:

```bash
.dependency/iopaint/.venv/Scripts/python.exe .ai/image-inpaint-region/inpaint.py --image image/foo.png --region 148,248,48 -o image/foo_inpainted
```

## How it works

1. Open the image as RGB (same as `iopaint` batch processing).
2. Draw a filled circle mask from `--region cx,cy,r`.
3. Binarize mask at **127** (same as `iopaint.batch_processing` / API).
4. Call `ModelManager` with **`InpaintRequest()` defaults**.
5. Write PNG via `pil_to_bytes(..., "png", 100, ...)`.

## IOPaint defaults used

These come from `InpaintRequest()` and `iopaint run` — the script does not override them:

| Setting | Default | Notes |
|---------|---------|-------|
| `--model` | `lama` | Same as `iopaint run` |
| `--device` | `cpu` | Same as `iopaint run` / `start`; use `--device cuda` when GPU is available |
| `hd_strategy` | `Crop` | LaMa erase-model preprocessing |
| `hd_strategy_crop_trigger_size` | `800` | Crop when long side > 800 px |
| `hd_strategy_crop_margin` | `128` | Margin around mask for crop strategy |
| Mask threshold | `127` | `>= 127 → 255`, else `0` |

The skill only adds `--region cx,cy,r` so you do not need a separate mask file.

## Options

| Option | Default | Notes |
|--------|---------|-------|
| `--image` | **Required** | Single supported image file |
| `--region` | **Required** | `cx,cy,r` — center x, center y, radius in pixels |
| Output | `<image-dir>/image-inpaint-region/<name>.png` | Use `-o` / `--output` for custom file or directory |
| `--model` | `lama` | IOPaint model name |
| `--device` | `cpu` | `cpu` or `cuda` (falls back via IOPaint `check_device`) |

Supported inputs: `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.avif`, `.ico`.

## Agent Workflow

1. **Confirm source** — user path only; do not copy into `image/` or use chat attachment cache.
2. **Confirm region** — inspect the image and determine circle center `(cx, cy)` and radius `r` before running.
3. **One file per run** — process one image, verify the result, then repeat for additional files if needed.
4. **Inspect** — check the inpainted area; leftover content → larger `r`; nearby art eaten → smaller `r` or move center.
5. **Revert** — delete the output file or `git restore`; sources are never modified.

## Agent Notes

1. Use the bundled script, not hand-written IOPaint CLI with separate mask files unless the user already has a mask image.
2. Missing iopaint venv → populate `.dependency/` per dependency-manager, retry same command.
3. **Do not copy, move, or replace the source with inpainted output** — tell the user where the output file is.
4. For full IOPaint UI / brush mask editing, use the upstream `iopaint start` workflow instead.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `iopaint` missing / not populated | Follow **Setup**; update manifest |
| Missing `--region` | Inspect image; both `--image` and `--region cx,cy,r` are required |
| Invalid `--region` | Must be three numbers: center x, center y, radius (> 0) |
| Directory passed to `--image` | Run once per file; this skill accepts image files only |
| Output already exists | Delete the existing output or choose a different `-o` path |
| CUDA not available | IOPaint falls back to `cpu` via `check_device` |
| Target still visible | Increase radius `r` in `--region` |
| Nearby art eaten | Decrease radius `r`; adjust center `(cx, cy)` |
| Wrong interpreter | Must use `.dependency/iopaint/.venv/Scripts/python.exe` |


## CLI

Copy-paste commands: [cli/image-inpaint-region.md](../../../cli/image-inpaint-region.md)

## Related

- Engine: [Sanster/IOPaint](https://github.com/Sanster/IOPaint) (LaMa)
- Upstream batch CLI: `iopaint run --model lama --device cpu --image ... --mask ... --output ...`
