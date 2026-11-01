---
name: audio-split
description: Splits a single audio file into two segments (part 1 before the split point, part 2 after) using FFmpeg. Use when the user wants to split audio, divide a clip into two parts, cut at a timestamp, or separate intro from body.
---

# Audio Split

Split one audio file into **part 1** (start → split point) and **part 2** (split point → end).

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default: split at **50%** of duration, output to `<audio-dir>/audio-split/`:

```bash
.dependency/python/python .ai/audio-split/split.py --audio path/to/audio.wav
```

Split at a specific time (seconds):

```bash
.dependency/python/python .ai/audio-split/split.py --audio path/to/audio.wav -s 1.25
```

Outputs: `basename_part1.ext` and `basename_part2.ext`.

## Split Point

Provide **one** of:

| Flag | Meaning |
|------|---------|
| `-s` / `--split-at` | Time in seconds (e.g. `1.25`, `90`) |
| `-p` / `--percent` | Position as percent of duration (e.g. `50` = midpoint) |
| *(none)* | Defaults to **50%** |

If both `-s` and `-p` are given, `-s` wins.

## Common Flags

`--audio` · `-s` / `--split-at` · `-p` / `--percent` · `-o` / `--output`

```bash
.dependency/python/python .ai/audio-split/split.py --audio audio/sfx.wav -s 0.4
.dependency/python/python .ai/audio-split/split.py --audio audio/sfx.wav --output path/to/out/
```

Originals are never modified. Supported: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

## Agent Notes

1. Use the bundled script, not hand-written `-ss`/`-to` commands.
2. **Looping BGM** — splitting breaks the loop; prefer two source assets or manual crossfade planning.
3. Split point at `0` or at/after duration → script errors with a clear message.
4. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.
5. FFmpeg details and manual fallback: [reference.md](reference.md)

## Tests

From repo root:

```bash
.dependency/python/python .ai/audio-split/test_split.py
```

Manual CLI examples: [cli/audio-split.md](../../../cli/audio-split.md)
