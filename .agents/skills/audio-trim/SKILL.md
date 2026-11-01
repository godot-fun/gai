---
name: audio-trim
description: Trims leading and trailing silence from audio files using FFmpeg. Use when the user wants audio trim, trim silence at start/end, remove leading/trailing silence, batch SFX cleanup, or voice dialogue preprocessing.
---

# Audio Trim

Remove leading/trailing silence via FFmpeg `silenceremove`.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default: threshold **-50 dB**, both sides, output to `<audio-dir>/audio-trim/<audio-name>`:

```bash
.dependency/python/python .ai/audio-trim/trim.py --audio path/to/audio.wav
```

Custom threshold:

```bash
.dependency/python/python .ai/audio-trim/trim.py --audio audio/sfx.wav -t -45
```

## Thresholds

| Asset | Threshold |
|-------|-----------|
| UI / SFX / voice | -50 dB (default) |
| Clipped attack / noisy room | -40 to -45 dB |
| Ambience / loops | -60 dB or skip |

## Common Flags

`--audio` · `-t` / `--threshold` · `-o` / `--output`

```bash
.dependency/python/python .ai/audio-trim/trim.py --audio audio/sfx.wav -t -50
```

Originals are never modified. Input must be a single audio file (`--audio`), not a directory. Supported: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script, not ad-hoc `-ss`/`-to`.
2. **Looping BGM** — avoid end-trim; can break loop seams. Skip this skill or trim manually.
3. Attack or reverb cut off → raise `-t` (e.g. `-45` or `-40`).
4. FFmpeg filter details: [reference.md](reference.md)

## CLI

Copy-paste commands: [cli/audio-trim.md](../../../cli/audio-trim.md)
