---
name: audio-fade
description: Applies fade-in and fade-out at the start and end of a single audio file using FFmpeg. Use when the user wants audio fade, fade in/out, smooth attack/release, crossfade prep, SFX envelope shaping, or mentions afade.
---

# Audio Fade

Apply **fade-in** at the start and **fade-out** at the end without changing clip length.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default: **1 s** fade-in and fade-out, output to `<audio-dir>/audio-fade/<audio-name>`:

```bash
.dependency/python/python .ai/audio-fade/fade.py --audio path/to/audio.wav
```

Fade-in only (keep full end level):

```bash
.dependency/python/python .ai/audio-fade/fade.py --audio path/to/audio.wav --no-fade-out
```

Custom durations (seconds):

```bash
.dependency/python/python .ai/audio-fade/fade.py --audio audio/sfx.wav -fi 0.05 -fo 0.15
```

## Duration Guidelines

| Asset | Fade-in | Fade-out |
|-------|---------|----------|
| UI clicks / ticks | 0.01–0.05 s | 0.02–0.08 s |
| Impacts / weapons | 0.02–0.08 s | 0.05–0.15 s |
| Voice lines | 0.05–0.15 s | 0.1–0.25 s |
| Ambience beds | 0.3–1.0 s | 0.5–2.0 s |
| BGM one-shots | 0.2–0.5 s | 0.3–1.0 s |

Fade-in + fade-out must stay **shorter than file duration**. Very short clips need smaller values.

## Common Flags

`--audio` · `-fi` / `--fade-in` · `-fo` / `--fade-out` · `--no-fade-in` · `--no-fade-out` · `-o` / `--output`

```bash
.dependency/python/python .ai/audio-fade/fade.py --audio audio/sfx.wav -fi 0.03 -fo 0.08
```

Originals are never modified. Input must be a single audio file (`--audio`), not a directory. Supported: `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, `.wma`.

Fades use FFmpeg `afade` with the linear `tri` curve. The script probes clip duration and places fade-out at `duration - fade_out`.

## Scope

- **Fade** shapes volume at clip boundaries without changing its duration.
- **Trim** removes silence or crops boundaries; use the `audio-trim` skill.
- **Crossfade** overlaps two clips and is not performed by this skill.

## Agent Notes

1. Use the bundled script, not hand-written `afade` filters.
2. **Looping BGM** — avoid fade-out on loop assets; use `--no-fade-out` or fade-in only for one-shot intros.
3. Clicks with instant attack → `--no-fade-in` or lower `-fi` (e.g. `0.01`).
4. Tail cut off abruptly after fade → increase `-fo`; tail too soft → decrease `-fo`.

## CLI

Copy-paste commands: [cli/audio-fade.md](../../../cli/audio-fade.md)
