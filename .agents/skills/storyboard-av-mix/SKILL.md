---
name: storyboard-av-mix
description: >-
  Muxes language-specific per-shot videos with Chinese and English voice-over,
  retiming video to match VO duration and writing separate Chinese/ and English/
  output folders. Use for storyboard A/V mixing, bilingual dubbing, video retime
  to audio, or batch muxing Audio/Chinese|English with Video/Chinese|English.
---

# Storyboard AV Mix

Pair Chinese video with Chinese VO and English video with English VO. Treat VO
duration as immutable, retime video only, drop source video audio, and mux the
matching narration.

Read and follow [dependency-manager](../dependency-manager.md). Run batches only
through `.ai/storyboard-av-mix/mix.py`.

## Layout

```text
workspace/
  Audio/
    Chinese/01.wav
    English/01.wav
  Video/
    Chinese/01.mp4
    English/01.mp4
  Output/
    Chinese/01.mp4
    English/01.mp4
```

Match by language and filename stem:

```text
Audio/Chinese/01.wav + Video/Chinese/01.mp4 -> Output/Chinese/01.mp4
Audio/English/01.wav + Video/English/01.mp4 -> Output/English/01.mp4
```

## Run

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video --output path/to/Output
```

`--audio` and `--video` are required. `--output` defaults to `<audio>/Video`.
Use `--lang chinese` or `--lang english` for one language; the default is
`both`.

## Rules

1. Never stretch, shrink, pad, trim, or apply `atempo` to VO. Use each VO file
   as that language's master clock.
2. Retime only the matching language video with FFmpeg `setpts`, adding a short
   freeze tail before `-shortest` handles frame rounding.
3. Match `Chinese` only with `Chinese`, and `English` only with `English`. Never
   fall back across languages.
4. Match files by stem (`01.mp4` with `01.wav`). Skip a missing language pair
   with a warning.
5. Drop source video audio. Prefer audio stream copy; encode AAC only when the
   output container cannot hold the VO codec.
6. Preserve source video codec class, pixel format, bitrate when known, color
   tags, metadata, and supported HDR metadata.
7. Never overwrite input video or VO. If the default output resolves to the
   input video folders, require a different `--output`.
8. A legacy flat video root (`Video/01.mp4`) may serve both languages only when
   neither `Video/Chinese` nor `Video/English` exists. Emit a warning.

## Output

Write `<output>/Chinese/<id>.<video-ext>` and
`<output>/English/<id>.<video-ext>`. Existing output files may be replaced;
inputs must remain untouched.

Report the resolved audio, video, and output roots; completed and failed job
counts; skipped pairs; and both language output folders.

## Tests

```bash
.dependency/python/python .ai/storyboard-av-mix/test_mix.py
```

Related: [storyboard-tts](../storyboard-tts/SKILL.md). Manual commands:
[cli/storyboard-av-mix.md](../../../cli/storyboard-av-mix.md).
