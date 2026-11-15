---
name: storyboard-av-mix
description: >-
  Muxes per-shot storyboard video with Chinese and English voice-over by retiming
  video to match VO duration (setpts), writing Video-Chinese/ and Video-English/
  (matched by shot id 01, 02, …). Use when the user wants storyboard A/V mix,
  VO dubbing mix, video retime to audio, Video-Chinese, Video-English,
  bilingual VO on cut video, or batch mux Video/ + Chinese/ + English/.
---

# Storyboard AV Mix

Take an **audio dir** with bilingual VO plus a **clip dir** with per-shot video. For each shot, **retime the video to the full VO duration** (audio master), drop original video audio, mux, and write language-specific folders next to the VO.

Two paths drive every run — pass them explicitly:

```bash
mix.py --audio path/to/<vo-dir> --video path/to/Video
```

| Input | Path |
|-------|------|
| Chinese VO | `<audio>/Chinese/<shot-id>.*` |
| English VO | `<audio>/English/<shot-id>.*` |
| Shot video | `<video>/<shot-id>.*` |

| Output | Path |
|--------|------|
| Chinese mux | `<audio>/Video-Chinese/<shot-id>.<video-ext>` |
| English mux | `<audio>/Video-English/<shot-id>.<video-ext>` |

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

1. **VO timing is immutable.** Never stretch, shrink, pad, trim, or `atempo` the voice-over. Duration of the VO file is the master clock.
2. **Video serves audio.** Only change video duration (FFmpeg `setpts`) so it equals that shot’s VO length, then mux.
3. Drop all audio from the source video; replace with the VO track. Prefer `-c:a copy`; if the container cannot hold the VO codec (e.g. WAV→MP4), encode AAC **without** changing length.
4. **Preserve source quality characteristics.** `setpts` requires a re-encode. The bundled script keeps HEVC/10-bit sources in H.265 Main10, preserves source `pix_fmt`, bitrate when known, color tags, and supported HDR metadata (mastering display / MaxCLL); other sources currently encode with H.264 while retaining their reported pixel format and color tags. Copy available container and video-stream metadata from the source clip.
5. Match shots by **filename stem** (`01.mp4` ↔ `01.wav`).
6. **Two required paths, no guessing.** `--audio` is the VO dir (`Chinese/` + `English/`); `--video` is the clip dir. Both must be passed — there is no positional path and no auto-detection. Outputs always stay under `<audio>/`.
7. Batch only via `.ai/storyboard-av-mix/mix.py` — do not hand-write FFmpeg mux/retime commands.
8. Never overwrite inputs under the clip dir, `Chinese/`, or `English/`.

## Quick Start

From project root:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/<vo-dir> --video path/to/Video
```

Single language:

```bash
.dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/<vo-dir> --video path/to/Video --lang chinese
```

Per shot / language the script:

1. Validates both required dirs (`--audio`, `--video`)
2. Probes VO duration (source of truth) and video duration
3. Applies `setpts=PTS*(vo_dur/video_dur)` — stretch or compress **video only** (plus short freeze-tail so video ≥ VO)
4. Muxes with `-shortest` so the output follows the VO clock (minor frame/container rounding may remain)
5. Writes `<audio>/Video-Chinese|` or `Video-English/` / `<shot-id>.<same-ext>`

## Layout

```
workspace/
  Video/             # clip dir (--video)
    01.mp4
    02.mp4
  vo/                # audio dir (--audio)
    Chinese/01.wav
    English/01.wav
    Video-Chinese/   # written by this skill
      01.mp4
      02.mp4
    Video-English/
      01.mp4
      02.mp4
```

The clip dir may live inside the audio dir (`vo/Video/`) or outside it (`workspace/Video/`) — either way `--video` must name the folder that holds `01.mp4`, `02.mp4`, …. Typical `<audio>` is a [storyboard-tts](../storyboard-tts/SKILL.md) output dir; nothing is inferred from the tree.

## Common Flags

| Flag | Notes |
|------|--------|
| `--audio` | Required. VO work dir with `Chinese/` and `English/` |
| `--video` | Required. Clip dir with `01.mp4`, `02.mp4`, … |
| `--lang` | `both` (default), `chinese`, `english` |

Existing outputs are overwritten. Missing VO for a language → skip that job with a warning. A shot without a matching VO file is skipped. Missing flag → argparse error; a flag pointing at a missing dir → `Audio dir not found` / `Video dir not found`, exit code 1.

## Agent Notes

1. Audio first: if durations disagree, change **video**, never VO.
2. Prefer one `mix.py` run for the whole board.
3. Ask for both paths before running — the script has no fallback and will stop without them.
4. Verify the reported output profile for high-bit-depth/HDR sources; the script must not force those sources to 8-bit H.264.
5. Chat summary: resolved audio dir + clip dir, jobs done / skipped, paths to `Video-Chinese/` and `Video-English/`.
6. Upstream VO usually from [storyboard-tts](../storyboard-tts/SKILL.md); this skill does not synthesize speech.
7. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, retry same command.

## Tests

From repo root:

```bash
.dependency/python/python .ai/storyboard-av-mix/test_mix.py
```

## Related

- [storyboard-tts](../storyboard-tts/SKILL.md) — bilingual VO under `Chinese/` / `English/`
- [storyboard](../storyboard/SKILL.md) — source markdown

Manual CLI examples: [cli/storyboard-av-mix.md](../../../cli/storyboard-av-mix.md)
