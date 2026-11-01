---
name: storyboard-tts
description: >-
  Converts storyboard markdown (bilingual Chinese + English narration per shot)
  into speech audio via IndexTTS2 (same stack as ai-text-to-speech). Batch-writes
  WAVs under Chinese/ and English/ named by shot id (model loaded once), pads
  0.4 s edge silence in place, then a speech-timeline.md and one concatenated
  SRT per language (Chinese.srt / English.srt). Use when the user wants
  storyboard TTS, storyboard to speech, narration VO, storyboard-to-speech, bilingual VO export,
  subtitles, or batch TTS from a storyboard.md.
---

# Storyboard TTS

Take a **[storyboard](../storyboard/SKILL.md)** deliverable and batch-synthesize **Chinese + English** voice-over with IndexTTS2 (shared setup with **[ai-text-to-speech](../ai-text-to-speech/SKILL.md)**).

| Output | Path |
|--------|------|
| Chinese VO | `<storyboard-dir>/<voice-stem>/Chinese/<shot-id>.wav` |
| English VO | `<storyboard-dir>/<voice-stem>/English/<shot-id>.wav` |
| Duration doc | `<storyboard-dir>/<voice-stem>/speech-timeline.md` |
| Chinese subs | `<storyboard-dir>/<voice-stem>/Chinese.srt` |
| English subs | `<storyboard-dir>/<voice-stem>/English.srt` |

Shot id from headers (`### Shot 01 — …` → `01.wav`).

Subtitles: **one SRT per language**. Shots are laid end-to-end on the VO timeline (shot N starts when N−1 ends). Inside a shot, text is split on sentence punctuation (`.!?;…` and CJK equivalents) into multiple cues; cue lengths share that shot’s WAV duration by **non-whitespace character weight**. Skip `(no VO)` / missing audio.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

1. **Batch synthesis only via** `.ai/storyboard-tts/synthesize.py` with the **`index-tts`** interpreter. Do **not** hand-write IndexTTS loops, temporary batch drivers, or N× single `tts.py` calls for a full storyboard.
2. **Trial / single-line** checks may use [ai-text-to-speech](../ai-text-to-speech/SKILL.md) `tts.py`, or `synthesize.py --limit 1`.
3. Parse-only / report-only / subtitle-only steps use stdlib **`python`** (`.dependency/python/python`).
4. Never overwrite the storyboard source. Write only under `<audio-dir>/`.
5. Skip `(no VO)` / empty lines — no empty WAVs or empty subtitle cues.
6. Confirm **voice reference** (and output dir if unclear) before a full batch.
7. The top-level output directory uses the reference voice filename stem. Subdirectory names stay fixed. Default `<audio-dir>` is `<storyboard-dir>/<voice-stem>/`. Do **not** use `<storyboard-stem>-speech`.

## Inputs

| Required | Notes |
|----------|--------|
| Storyboard `.md` | `### Shot NN — title` with `- **Chinese:**` / `- **English:**` |
| Reference voice | WAV/MP3 for IndexTTS (`--voice`, or `--voice-zh` / `--voice-en`) |

| Optional | Default |
|----------|---------|
| Output dir | `<storyboard-dir>/<voice-stem>/` (reference audio filename, no extension) |
| Language | both (`--lang chinese` / `english`) |
| `--fp16` / emotion / `--device` | same meaning as ai-text-to-speech |
| `--force` | off (skip existing WAVs) |
| `--limit N` | 0 = all jobs (use `1` for trial) |
| `--report` | write `speech-timeline.md` + `Chinese.srt` / `English.srt` after synth |
| `--no-subtitles` | with `--report`, skip SRT files |
| Edge pad | on (`0.4` s); `--no-pad` / `--pad-duration` / `--pad-threshold` |

## Layout

```
<storyboard-dir>/<voice-stem>/   # e.g. narrator-self-fast/ from narrator-self-fast.wav
  Chinese/
    01.wav
    …
  English/
    01.wav
    …
  shots.json
  speech-timeline.md
  Chinese.srt            # all Chinese cues, continuous timeline
  English.srt            # all English cues, continuous timeline
  _text/                 # only with --write-text
```

## Quick Start

From project root:

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice path/to/ref.wav --fp16 --report
```

Trial run (first line only):

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice path/to/ref.wav --fp16 --limit 1
```

Writes under `<storyboard-dir>/<voice-stem>/` (override with `--audio-dir` only when needed).

This will:

1. Parse the storyboard → `<audio-dir>/shots.json`
2. Load IndexTTS2 **once**
3. Write `Chinese/<id>.wav` and `English/<id>.wav` (skip existing unless `--force`)
4. Pad each WAV in place to **0.4 s** leading/trailing silence (`--no-pad` to skip)
5. Write `speech-timeline.md` and `Chinese.srt` / `English.srt` when `--report`

### Separate voices / language

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice-zh path/to/zh_ref.wav --voice-en path/to/en_ref.wav --fp16 --report
```

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice path/to/ref.wav --lang chinese --fp16 --report
```

### Parse, report, or subtitles alone (stdlib python)

```bash
.dependency/python/python .ai/storyboard-tts/parse_storyboard.py path/to/storyboard.md -o path/to/<audio-dir>/shots.json
```

```bash
.dependency/python/python .ai/storyboard-tts/duration_report.py --storyboard path/to/storyboard.md --audio-dir path/to/<audio-dir> --shots path/to/<audio-dir>/shots.json -o path/to/<audio-dir>/speech-timeline.md
```

```bash
.dependency/python/python .ai/storyboard-tts/write_subtitles.py --audio-dir path/to/<audio-dir> --shots path/to/<audio-dir>/shots.json
```

Resume from an existing `shots.json`:

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --shots path/to/<audio-dir>/shots.json --voice path/to/ref.wav --fp16 --report
```

## Common Flags (synthesize.py)

| Flag | Notes |
|------|--------|
| `--storyboard` / `--shots` | Source (one required) |
| `--audio-dir` | Output root (default: `<storyboard-dir>/<voice-stem>/`) |
| `--voice` | Shared speaker ref |
| `--voice-zh` / `--voice-en` | Per-language refs |
| `--lang` | `both` (default), `chinese`, `english` |
| `--limit N` | First N pending jobs only |
| `--force` | Overwrite existing WAVs |
| `--report` | Write timeline + SRT subtitles |
| `--report-out` | Custom timeline path |
| `--no-subtitles` | Skip SRT when using `--report` |
| `--write-text` | Dump lines under `_text/` |
| `--no-pad` | Skip in-place 0.4 s edge padding (off by default — padding is on) |
| `--pad-duration` | Target silence per edge in seconds (default: `0.4`) |
| `--pad-threshold` | Silence detect threshold in dB (default: `-50`) |
| `--fp16` / `--device` | Runtime |
| `--emotion-*` / `--random` / `--verbose` | Same role as `tts.py` |

On partial failure: script continues remaining jobs, prints `Failed jobs: …`, exit code `1`. Fix install/voice per ai-text-to-speech troubleshooting, re-run (existing OK files are skipped).

## Agent Notes

1. Do **not** invent narration — use storyboard Chinese/English fields as-is (audio and subtitles).
2. Prefer **one** `synthesize.py` invocation for a full board; model reload cost is the reason.
3. Chat summary: `audio-dir` (`<storyboard-dir>/<voice-stem>/`), counts, path to `speech-timeline.md`, `Chinese.srt` / `English.srt`, Chinese/English total seconds — no full transcripts unless asked. Omit `--audio-dir` unless overriding.
4. IndexTTS install lives in [ai-text-to-speech](../ai-text-to-speech/SKILL.md); do not duplicate Setup here beyond “populate index-tts if missing”.
5. Edge padding is **built in** (default 0.4 s, in place via `pad.py`). Use `--no-pad` only when they want raw TTS with no extra silence; `--pad-duration` if they want a different length.
6. Loudnorm / OGG / trim remain separate skills after this one.
7. If audio already exists and only subtitles are needed, run `write_subtitles.py` alone (stdlib python). Re-running `synthesize.py --report` without `--force` still pads existing WAVs, then rewrites the timeline/SRT.

## Tests

Stdlib scripts (from repo root):

```bash
.dependency/python/python .ai/storyboard-tts/test_parse_storyboard.py
.dependency/python/python .ai/storyboard-tts/test_write_subtitles.py
```

IndexTTS batch driver (requires populated `index-tts`; see `cli/storyboard-tts.md`):

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice .ai/test/audio/han.wav --fp16 --limit 1 --report
```

## Related

- [storyboard](../storyboard/SKILL.md) — source markdown
- [ai-text-to-speech](../ai-text-to-speech/SKILL.md) — single-line TTS + IndexTTS setup
- [storyboard-av-mix](../storyboard-av-mix/SKILL.md) — mux VO with per-shot video
- Optional after: [audio-loudness-normalization](../audio-loudness-normalization/SKILL.md)
