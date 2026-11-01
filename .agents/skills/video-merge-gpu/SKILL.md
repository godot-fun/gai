---
name: video-merge-gpu
description: >-
  Merges multiple videos from a folder (sorted by filename) into one clip with a
  random xfade transition (0.5s) between each pair; freeze-pads so total duration
  equals the sum of sources. Encodes with GPU HEVC only (NVENC / AMF / QSV — no
  CPU libx265 fallback). Exports 3840×2160 60fps H.265 Main10 40Mbps + AAC
  320kbps. Use when the user wants video-merge-gpu, GPU video merge, NVENC merge,
  hevc_nvenc concat, GPU concat, GPU video merge, or batch stitch clips with xfade on GPU.
disable-model-invocation: true
---

# Video Merge GPU

Same merge as [`video-merge`](../video-merge/SKILL.md): concatenate every video in a folder (filename sort) into **one** high-quality MP4, random FFmpeg `xfade` (0.5s) + matching `acrossfade`, freeze-pad so output length equals the sum of source durations.

**GPU encode only.** Probe `hevc_nvenc` → `hevc_amf` → `hevc_qsv` (HEVC Main10). If none work, **fail** — do not fall back to `libx265`. Use `video-merge` when CPU encode is wanted.

xfade / scale / pad still run on CPU; only the H.265 encode is hardware.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `merge.py` through **`.dependency/python/python.exe`**. Never use host `python` / `ffmpeg`.
- **Never overwrite sources.** Outputs go under `video-merge-gpu/`.
- Use the bundled script — do not hand-write equivalent FFmpeg commands.
- **Folder input only** — pass `--folder` with a directory of clips (top-level files; no recurse).

## Quick Start

```bash
.dependency/python/python .ai/video-merge-gpu/merge.py --folder path/to/clips
```

Example:

```
assets/shots/
  01.mp4
  02.mp4
  03.mp4
→ assets/shots/video-merge-gpu/shots.mp4
```

## Output Spec (fixed)

| Setting | Value |
|---------|-------|
| Resolution | 3840×2160 (scale + letterbox pad) |
| Frame rate | 60 fps |
| Video | H.265 Main10 (GPU: `hevc_nvenc` / `hevc_amf` / `hevc_qsv`, `p010le`) @ **40 Mbps** |
| Audio | AAC **320 kbps**, 48 kHz stereo |
| Transition | **0.5 s**, random from the pool below (freeze-pad; duration preserved) |
| Container | `.mp4` (`hvc1` tag) |

## Transition Pool (random per cut)

`fade` · `dissolve` · `wipeleft` · `wiperight` · `wipeup` · `wipedown` · `slideleft` · `slideright` · `circlecrop` · `pixelize` · `distance` · `radial` · `smoothleft` · `smoothright` · `circleopen` · `circleclose` · `diagtl` · `diagtr` · `hblur` · `zoomin`

Each cut independently samples one transition. Printed in the run log.

## Common Flags

`--folder` · `-o` / `--output`

```bash
.dependency/python/python .ai/video-merge-gpu/merge.py --folder clips
.dependency/python/python .ai/video-merge-gpu/merge.py --folder clips -o out/final.mp4
```

**Never overwrite source files.** Input must be a folder (`--folder`), not a single video file. Only top-level videos in the folder (no recurse). Supported: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.wmv`, `.flv`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.mts`, `.m2ts`, `.3gp`, `.ogv`.

## Agent Notes

1. Use the bundled script — do **not** hand-write `ffmpeg` xfade chains.
2. Transition duration is fixed at **0.5s** — no duration override flag.
3. Every clip **except the first** must be **longer than 0.5s** (incoming side of `xfade`).
4. Single file in the folder → re-encode to the output spec with no transition.
5. Many clips (4K10) auto-chunk (max 8 inputs per filtergraph) to avoid OOM; transitions stay correct across chunk boundaries.
6. **No CPU fallback.** Missing GPU HEVC Main10 → report the probe failure; suggest `video-merge` only if the user accepts CPU.
7. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry.
8. FFmpeg filter / encoder details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/video-merge-gpu/test_merge.py
```

Manual CLI examples: [cli/video-merge-gpu.md](../../../cli/video-merge-gpu.md)
