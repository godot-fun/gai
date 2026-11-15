---
name: video-bgm
description: Adds background audio from one folder to a single video using FFmpeg. Naturally sorts, sequences, and crossfades the folder tracks, loops a short playlist or trims long audio to match the video, fades out at the end, and mixes it with the original audio while stream-copying the video. Use when the user wants to add BGM, background music, a soundtrack, or a music bed to a video.
---

# Video BGM

Add background audio from one folder to a single video. Folder audio plays in natural filename order with a crossfade. The resulting playlist loops when shorter than the video and is trimmed when longer.

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

- Run `add_bgm.py` through **`.dependency/python/python.exe`**. Never use host `python` / `ffmpeg`.
- **Never overwrite sources.** Outputs go under `video-bgm/` by default.
- Use the bundled script; do not hand-write equivalent FFmpeg commands.
- Pass one video file to `--video` and one audio folder to `--audio`.
- Read only audio files directly inside the folder; do not recurse into subfolders.

## Quick Start

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video path/to/clip.mp4 --audio path/to/music-folder
```

Audio folder:

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video path/to/clip.mp4 --audio path/to/music-folder
```

Example:

```text
assets/intro.mp4 + assets/calm.mp3
  → assets/video-bgm/intro.mp4
```

## Defaults

| Setting | Default |
|---------|---------|
| Audio order | Natural filename order within the folder |
| Between tracks | Up to 1 second crossfade |
| Short playlist | Loop until video ends |
| Long playlist | Trim to video duration |
| Ending | Up to 2 second BGM fade-out |
| Original audio | Preserve and mix at full volume |
| BGM volume | 20% |
| Video | Stream copy; no re-encode |

## Parameters

`--video` · `--audio` · `-o` / `--output`

```bash
.dependency/python/python .ai/video-bgm/add_bgm.py --video clip.mp4 --audio bgm.mp3 -o out/clip.mp4
```

## Agent Notes

1. Audio files are background tracks, not replacement soundtracks; the original video audio remains when present.
2. Use numbered filenames such as `01_intro.mp3`, `02_main.ogg` to control folder playback order.
3. The script uses fixed mixing defaults intentionally. Do not expose extra tuning flags.
4. A silent video receives the BGM directly.
5. Missing Python/FFmpeg → populate `.dependency/` per dependency-manager, then retry.
6. Tell the user where the `video-bgm/` output is; do not replace the source.
7. Pipeline details: [reference.md](reference.md)

## Tests

From the repository root:

```bash
.dependency/python/python .ai/video-bgm/test_add_bgm.py
```

Manual CLI examples: [cli/video-bgm.md](../../../cli/video-bgm.md)
