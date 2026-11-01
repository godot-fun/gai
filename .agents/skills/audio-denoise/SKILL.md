---
name: audio-denoise
description: Reduces background noise in a single audio file using FFmpeg afftdn. Use when the user wants audio denoise, noise reduction, hiss removal, room noise cleanup, or SFX/voice cleanup before normalization.
---

# Audio Denoise

Reduce background noise via FFmpeg `afftdn`.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Denoise a single audio file, output to `<audio-dir>/audio-denoise/<audio-name>`:

```bash
.dependency/python/python .ai/audio-denoise/denoise.py --audio path/to/audio.wav
```

## Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Denoise | `afftdn` | `nr=10` dB, `nf=-25` dB — conservative for SFX |

## Common Flags

`--audio` · `--nr` · `--nf` · `--output`

```bash
.dependency/python/python .ai/audio-denoise/denoise.py --audio Audio/SFX/click.wav
.dependency/python/python .ai/audio-denoise/denoise.py --audio Audio/Voice/line.wav --nr 8
```

Originals are never modified. Input must be a single audio file (`--audio`), not a directory. Supported: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script, not hand-written `afftdn` filters.
2. **Default is light denoise** — do not raise `--nr` unless the user asks; heavy denoise dulls transients.
3. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
4. **Do not copy, move, or replace the source with denoised output** — tell the user where `audio-denoise/` files are; they swap assets manually when ready.

## Tests

From repo root:

```bash
.dependency/python/python .ai/audio-denoise/test_denoise.py
```

Manual CLI examples: [cli/audio-denoise.md](../../../cli/audio-denoise.md)
