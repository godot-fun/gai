---
name: audio-sample-rate-standardize
description: Standardizes a single audio file to 44100 or 48000 Hz and exports 16-bit PCM WAV using FFmpeg. Use when the user wants sample rate standardization, resample to 44.1 kHz or 48 kHz, WAV export at project sample rates, or mentions 44100, 48000, or PCM WAV conversion without loudness normalization.
---

# Audio Sample Rate Standardize

Export **16-bit PCM WAV** at **44100 or 48000 Hz** only. No loudness processing. Directories are not supported; run once per file to process a folder.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default output: `<audio-dir>/audio-sample-rate-standardize/<name>.wav` (source files are read-only):

```bash
.dependency/python/python .ai/audio-sample-rate-standardize/standardize.py --audio path/to/audio.mp3
```

Example: `audio/sfx/tank/tank_move.mp3` → `audio/sfx/tank/audio-sample-rate-standardize/tank_move.wav`

## Sample Rate Rule

| Source rate | Output |
|-------------|--------|
| ≤ 44100 Hz | 44100 Hz |
| > 44100 Hz | 48000 Hz |

| Rate | Typical use |
|------|-------------|
| 44100 Hz | Music, games, CD |
| 48000 Hz | Games, film, video |

## Common Flags

`--audio` · `--output`

```bash
.dependency/python/python .ai/audio-sample-rate-standardize/standardize.py --audio Audio/SFX/tank_move.mp3 --output Audio/SFX/out
```

**Never overwrite source files.** The script writes only to `audio-sample-rate-standardize/` (or `--output`). All outputs are `.wav` regardless of input format. Supported inputs: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script, not hand-written `-ar` / `-c:a` commands.
2. **No loudness normalization** — LUFS targeting is a separate step in the audio pipeline.
3. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
4. **Do not copy, move, or replace the source with the output** — tell the user where `audio-sample-rate-standardize/` files are; they swap assets manually when ready.
5. Do not use `--output` pointing at the source file; the script refuses paths that would overwrite the input.
6. FFmpeg details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/audio-sample-rate-standardize/test_standardize.py
```

Manual CLI examples: [cli/audio-sample-rate-standardize.md](../../../cli/audio-sample-rate-standardize.md)
