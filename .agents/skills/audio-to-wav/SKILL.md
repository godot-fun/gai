---
name: audio-to-wav
description: Converts a single audio file to WAV (PCM) using FFmpeg while preserving source quality. Use when the user wants to convert audio to WAV, transcode MP3/OGG/FLAC/AAC to WAV without downgrading sample rate or bit depth, or export a lossless WAV source asset.
---

# Audio to WAV

Convert a supported audio file to **PCM WAV** via FFmpeg. **Defaults preserve source quality** — sample rate is always kept, bit depth matched from the source (32-bit float for lossy inputs), channels preserved.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default output: `<audio-dir>/audio-to-wav/<basename>.wav`

```bash
.dependency/python/python .ai/audio-to-wav/convert.py --audio path/to/audio.flac
```

Example: `audio/sfx/tank/tank_move.flac` → `audio/sfx/tank/audio-to-wav/tank_move.wav` (same rate/depth)

## Format Defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Sample rate | Preserve source | Always kept; no resampling |
| Bit depth | Match source | Probed per file; lossy → 32-bit float PCM |
| Channels | Preserve source | Always kept from source audio |
| Existing PCM WAV | Stream copy | Bit-perfect when no overrides |

## Common Flags

`--audio` · `-o` / `--output` · `-b` / `--bit-depth`

Force 16-bit PCM:

```bash
.dependency/python/python .ai/audio-to-wav/convert.py --audio path/to/audio.mp3 -b 16
```

Custom output path:

```bash
.dependency/python/python .ai/audio-to-wav/convert.py --audio path/to/audio.flac --output path/to/out.wav
```

**Never overwrite source files.** The script writes only under `audio-to-wav/` (or `--output`). Input must be a single audio file (`--audio`), not a directory. Supported inputs: `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`, `.wav`.

## Agent Notes

1. Use the bundled script, not hand-written `ffmpeg -i …` commands.
2. **Sample rate is always preserved** — use the `audio-sample-rate-standardize` skill if resampling is needed.
3. **Do not reduce bit depth** unless the user explicitly asks — omit `-b`.
4. **Already PCM WAV?** Stream-copied by default (no generation loss).
5. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
6. **Do not copy, move, or replace the source with converted output** — tell the user where output files are; they swap assets manually when ready.
7. FFmpeg codec and probing details: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/audio-to-wav/test_convert.py
```

Manual CLI examples: [cli/audio-to-wav.md](../../../cli/audio-to-wav.md)
