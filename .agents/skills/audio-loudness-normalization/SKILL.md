---
name: audio-loudness-normalization
description: Normalizes a single audio file to consistent LUFS loudness with true-peak limiting using FFmpeg. Use when the user wants loudness normalization, volume matching, unified audio levels, SFX/UI/BGM leveling, or mentions LUFS, true peak, loudnorm, or inconsistent game audio.
---

# Audio Loudness Normalization

Loudness-normalize one audio file to a target LUFS with true-peak limiting. **Preserves input format** — same extension and sample rate as the source. Directories are not supported; run once per file to process a folder.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default: **-14 LUFS**, **-1.5 dBTP**, output to `<audio-dir>/audio-loudness-normalization/<audio-name>`:

```bash
.dependency/python/python .ai/audio-loudness-normalization/normalize.py --audio path/to/audio.wav
```

Example: `audio/sfx/tank/tank_move.wav` → `audio/sfx/tank/audio-loudness-normalization/tank_move.wav`

## LUFS Targets

| Category | LUFS |
|----------|------|
| UI / clicks | -18 to -14 |
| Gameplay SFX | -16 to -12 |
| Explosions | -12 to -8 |
| Ambience | -22 to -18 |
| BGM / voice | -16 to -14 |

One category per folder. Mixed folders: split first, then normalize each file with matching `-t`.

## Common Flags

`--audio` · `-t` / `--target-lufs` · `-output`

```bash
.dependency/python/python .ai/audio-loudness-normalization/normalize.py --audio Audio/SFX/click.wav -t -14
```

**Never overwrite source files.** The script writes only to `audio-loudness-normalization/` (or `-output`). Supported inputs: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script (two-pass `loudnorm`), not hand-written FFmpeg.
2. **Preserves input format** — same extension and sample rate (`-ar` forced to source); does not resample.
3. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
4. **Do not copy, move, or replace the source with the normalized output** — tell the user where `audio-loudness-normalization/` files are; they swap assets manually when ready.
5. Do not use `-output` pointing at the source file; the script refuses paths that would overwrite the input.
6. Do not fix uneven levels with per-asset volume in game code — re-normalize sources.
7. Engine bus defaults and rationale: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/audio-loudness-normalization/test_normalize.py
```

Manual CLI examples: [cli/audio-loudness-normalization.md](../../../cli/audio-loudness-normalization.md)
