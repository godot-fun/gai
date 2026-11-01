---
name: storyboard-av-mix
description: >-
  Muxes per-shot storyboard video with Chinese and English voice-over by retiming
  video to match VO duration (setpts), writing Video-Chinese/ and Video-English/
  (matched by shot id 01, 02, …). Use when the user wants storyboard A/V mix,
  storyboard A/V mix, VO dubbing mix, video retime to audio, Video-Chinese, Video-English,
  bilingual VO on cut video, or batch mux Video/ + Chinese/ + English/.
---

# Storyboard AV Mix

Take a work directory with **per-shot** video and bilingual VO. For each shot, **retime the video to the full VO duration** (audio master), drop original video audio, mux, and write language-specific folders.

| Input | Path |
|-------|------|
| Shot video | `<root>/Video/<shot-id>.*` |
| Chinese VO | `<root>/Chinese/<shot-id>.*` |
| English VO | `<root>/English/<shot-id>.*` |

| Output | Path |
|--------|------|
| Chinese mux | `<root>/Video-Chinese/<shot-id>.<video-ext>` |
| English mux | `<root>/Video-English/<shot-id>.<video-ext>` |

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

1. **VO timing is immutable.** Never stretch, shrink, pad, trim, or `atempo` the voice-over. Duration of the VO file is the master clock.
2. **Video serves audio.** Only change video duration (FFmpeg `setpts`) so it equals that shot’s VO length, then mux.
3. Drop all audio from the source video; replace with the VO track. Prefer `-c:a copy`; if the container cannot hold the VO codec (e.g. WAV→MP4), encode AAC **without** changing length.
4. **Do not downgrade video.** `setpts` requires a re-encode, but match the source: codec family (H.265 Main10 when source is 10-bit HEVC), `pix_fmt`, bitrate, color tags, and HDR side data (mastering display / MaxCLL). Copy container + video-stream metadata from the source clip.
5. Match shots by **filename stem** (`01.mp4` ↔ `01.wav`).
6. Batch only via `.ai/storyboard-av-mix/mix.py` — do not hand-write FFmpeg mux/retime commands.
7. Never overwrite inputs under `Video/`, `Chinese/`, or `English/`.

## Quick Start

From project root:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py path/to/<root>
```

Single language:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py path/to/<root> --lang chinese
```

Per shot / language the script:

1. Probes VO duration (source of truth) and video duration
2. Applies `setpts=PTS*(vo_dur/video_dur)` — stretch or compress **video only** (plus short freeze-tail so video ≥ VO)
3. Muxes with `-shortest` so **container duration == VO duration**
4. Writes `<root>/Video-Chinese|` or `Video-English/` / `<shot-id>.<same-ext>`

## Layout

```
<root>/
  Video/
    01.mp4
    02.mp4
  Chinese/
    01.wav
    02.wav
  English/
    01.wav
    02.wav
  Video-Chinese/     # written by this skill
    01.mp4
    02.mp4
  Video-English/
    01.mp4
    02.mp4
```

Typical `<root>` is a [storyboard-tts](../storyboard-tts/SKILL.md) audio dir that also has a sibling or nested `Video/` of cut clips — confirm the folder that contains `Video/`, `Chinese/`, and `English/`.

## Common Flags

| Flag | Notes |
|------|--------|
| `root` | Work dir with `Video/`, `Chinese/`, `English/` |
| `--lang` | `both` (default), `chinese`, `english` |

Existing outputs are overwritten. Missing VO for a language → skip that job with a warning. Missing video → skip shot.

## Agent Notes

1. Audio first: if durations disagree, change **video**, never VO.
2. Prefer one `mix.py` run for the whole board.
3. Re-encode must preserve source quality tags (Main10 / HDR / bitrate) — never force 8-bit H.264.
4. Chat summary: `<root>`, jobs done / skipped, paths to `Video-Chinese/` and `Video-English/`.
5. Upstream VO usually from [storyboard-tts](../storyboard-tts/SKILL.md); this skill does not synthesize speech.
6. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.

## Tests

From repo root:

```bash
.dependency/python/python .ai/storyboard-av-mix/test_mix.py
```

## Related

- [storyboard-tts](../storyboard-tts/SKILL.md) — bilingual VO under `Chinese/` / `English/`
- [storyboard](../storyboard/SKILL.md) — source markdown

Manual CLI examples: [cli/storyboard-av-mix.md](../../../cli/storyboard-av-mix.md)
