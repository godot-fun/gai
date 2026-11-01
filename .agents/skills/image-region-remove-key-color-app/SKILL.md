---
name: image-region-remove-key-color-app
description: >-
  Interactive Gradio UI to paint a region and remove solid key-color background
  (white / green / magenta) only inside that selection. Use when enclosed white
  islands remain after border/both keying, for localized white-background cutout, paint-to-erase
  chroma patches, or selective color-key cleanup before Godot sprite import.
---

# Image Region Remove Key Color App

Paint a **region mask** in a local Gradio UI, then remove **key-color pixels only inside that region** (global keying scoped to the brush). Preserves white/light subject pixels outside the paint strokes.

Use after [image-remove-white-background](../image-remove-white-background/SKILL.md) when edge flood fill leaves enclosed white islands (e.g. gaps inside a silhouette).

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `app.py` through the **`image-region-remove-key-color-app` manifest entry** (`.dependency/image-region-remove-key-color-app/.venv/`). Never use host `python`, `py`, `python3`, or any interpreter outside `.dependency/`.
- Do not hand-write a one-off Gradio app — use the bundled script at `.ai/image-region-remove-key-color-app/app.py`.
- `populated: false` is not a reason to skip. Install first, set `populated: true`, retry the same command.
- This skill is **interactive**: launch the UI, give the user the local URL, wait for them to paint / Apply / Download.

## Setup (first run)

From project root:

```bash
.dependency/python/python -m venv .dependency/image-region-remove-key-color-app/.venv
.dependency/image-region-remove-key-color-app/.venv/Scripts/python.exe -m pip install Pillow gradio
```

If `python -m venv` fails (missing `venv` / `ensurepip`), create the env with `virtualenv` from another populated skill venv, then install packages into the new env:

```bash
.dependency/rembg/.venv/Scripts/python.exe -m pip install virtualenv
.dependency/rembg/.venv/Scripts/python.exe -m virtualenv .dependency/image-region-remove-key-color-app/.venv
.dependency/image-region-remove-key-color-app/.venv/Scripts/python.exe -m pip install Pillow gradio
```

Register in `.dependency/manifest.json`:

```json
"image-region-remove-key-color-app": {
  "populated": true,
  "bin": ".dependency/image-region-remove-key-color-app/.venv/Scripts/python.exe"
}
```

Use `bin/python` on Unix.

## Quick Start

```bash
# Preload an image (opens http://127.0.0.1:7860)
.dependency/image-region-remove-key-color-app/.venv/Scripts/python.exe .ai/image-region-remove-key-color-app/app.py path/to/sprite.png

# Custom port, no auto-open browser (agent / headless)
.dependency/image-region-remove-key-color-app/.venv/Scripts/python.exe .ai/image-region-remove-key-color-app/app.py path/to/sprite.png --port 7861 --no-browser
```

Download uses the **same filename** as the source (forced `.png`). No share / no save-to-disk folder.

## UI workflow

1. **Upload** the image via the file control (or preload via CLI) — do not drop into the editor canvas.
2. Transparent areas appear as **gray** in the editor (download still has real alpha).
3. **Paint** over local white / chroma patches to remove.
4. Choose **Key color** / tolerance / feather if needed.
5. Click **Apply** → preview (gray = transparent).
6. Click **Download** → browser download with the original name.
7. Click **Stop server** when done (or `Ctrl+C` in the terminal).

## Key color

Use the UI color picker (default `#FFFFFF`). CLI `--preset` only sets the initial color and tolerance:

| `--preset` | Key color | Default tolerance |
|------------|-----------|-------------------|
| `white` *(default)* | `#FFFFFF` | 25 |
| `green` | `#00FF00` | 40 |
| `magenta` | `#FF00FF` | 40 |

## Agent workflow

1. **When** — user needs selective / painted removal of flat key-color patches; full-image `global` would damage white subjects; `border`/`both` left enclosed islands.
2. **Ensure deps** — manifest entry + venv with Pillow + Gradio.
3. **Launch** — run `app.py` with the user image path; prefer `--no-browser` if the agent cannot open a GUI browser, and print `http://127.0.0.1:<port>`.
4. **Hand off** — tell the user to paint, Apply, then Download (same filename as source).
5. **Verify** — after the user confirms download, they are done; do not overwrite sources.
6. **Stop** — click **Stop server** in the UI, or terminate the Gradio process when the user is done.

## Defaults

| Option | Default | Notes |
|--------|---------|-------|
| Download name | same as source (`.png`) | Prepared on Apply via `DownloadButton` |
| `--preset` | `white` | Match the batch key skill |
| `--tolerance` | preset-specific | Raise for gray fringes |
| `--feather` | `2` | Softens hole edges inside the paint mask |
| `--port` | `7860` | Change if busy |
| Share | off | `share=False`; no share UI |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Manifest / venv missing | Follow **Setup**; update manifest |
| `No paint strokes found` | Brush visibly over the white islands; ensure strokes are on the editor layers |
| Subject holes outside paint | Only paint the background islands — strokes gate keying |
| Leftover fringe in region | Raise tolerance by 5–10 |
| Port in use | Pass `--port 7861` (etc.) |
| Gradio import error | Reinstall in the skill venv: `pip install -U Pillow gradio` |


## CLI

Copy-paste commands: [cli/image-region-remove-key-color-app.md](../../../cli/image-region-remove-key-color-app.md)

## Related

- Full-image / batch keying: [image-remove-white-background](../image-remove-white-background/SKILL.md)
- AI matting: [image-remove-background](../image-remove-background/SKILL.md)
