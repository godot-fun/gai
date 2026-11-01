---
name: audio-volume-adjust
description: Adjusts audio file volume up or down using FFmpeg. Use when the user wants to change volume, boost or reduce loudness, attenuate or amplify SFX/UI/BGM, apply dB gain, raise/lower clip levels, or batch-adjust audio amplitude.
---

# Audio Volume Adjust

Apply a uniform **gain change** across the full clip — no fade, no loudness targeting. Negative dB reduces level; positive dB increases it.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Reduce by 6 dB (~half amplitude), output to `<audio-dir>/audio-volume-adjust/<audio-name>`:

```bash
.dependency/python/python .ai/audio-volume-adjust/adjust.py --audio path/to/audio.wav --volume -6
```

Example: `audio/sfx/tank/tank_move.wav` → `audio/sfx/tank/audio-volume-adjust/tank_move.wav`

Boost by 3 dB:

```bash
.dependency/python/python .ai/audio-volume-adjust/adjust.py --audio audio/sfx.wav --volume 3
```

## Adjustment Guidelines

| Goal | `--volume` (dB) |
|------|-----------------|
| Slight reduction | -3 |
| Half amplitude | -6 |
| Noticeably quieter | -9 to -12 |
| Background / distant | -15 to -20 |
| Slight boost | +3 |
| Noticeably louder | +6 |

## Common Flags

`--audio` · `--volume` · `-o` / `--output`

```bash
.dependency/python/python .ai/audio-volume-adjust/adjust.py --audio audio/sfx.wav --volume -9
```

Originals are never modified. Input must be a single audio file (`--audio`), not a directory. Supported: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script, not hand-written `volume` filters.
2. Always pass `--volume` in dB (negative = reduce, positive = boost).
3. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
4. **Do not copy, move, or replace the source with the adjusted output** — tell the user where `audio-volume-adjust/` files are; they swap assets manually when ready.
5. Do not use `--output` pointing at the source file; the script refuses output paths that would overwrite inputs.
6. **Boosting** (positive dB) can clip peaks — warn the user; prefer small boosts (+3 dB or less).
7. FFmpeg filter details and dB math: [reference.md](reference.md)

## CLI

Copy-paste commands: [cli/audio-volume-adjust.md](../../../cli/audio-volume-adjust.md)
