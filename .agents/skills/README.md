# Skills

Batch asset tools — run from repo root; use each skill's script; never overwrite sources. Dependencies: [skill-dependency-manager](../skills/skill-dependency-manager.md). Commands and flags: see each skill's `SKILL.md`.

## Categories

| Category | Pipeline | Skills |
|----------|----------|--------|
| [AI](#ai) | Text-to-speech | 1 skill |
| [Audio](#audio) | to-wav → trim → loudness → export / transcription | 10 skills |
| [Image](#image) | to-png → watermark → split → background → trim / resize | 8 skills |
| [Video](#video) | mute / wav → 60fps → 4K → merge → compress / OGV | 10 skills |
| [Storyboard](#storyboard) | Storyboard → HTML preview / video → VO → AV mix → merge → publish | 4 skills |
| [Other](#other) | Naming, commits | 2 skills |

## AI

| Skill | Purpose |
|-------|---------|
| [ai-text-to-speech](ai-text-to-speech/SKILL.md) | Text → speech with voice clone (IndexTTS2; single-line / trial) |

## Audio

Batch audio cleanup for SFX / VO / BGM — convert, shape edges, clean noise, normalize, then export.

```
Source audio
    ↓
① audio-to-wav — working format (WAV recommended)
    ↓
② audio-trim — trim leading/trailing silence
    ↓
③ audio-split — cut / splice (optional)
    ↓
④ audio-denoise — denoise (optional)
    ↓
⑤ audio-fade — fade in/out (optional)
    ↓
⑥ audio-loudness-normalization  ·or·  audio-volume-adjust
    ↓
⑦ audio-sample-rate-standardize — 44100 / 48000 Hz WAV
    ↓
⑧ audio-to-ogg — export (BGM)  ·or·  keep WAV
```

| Skill | Purpose |
|-------|---------|
| [audio-to-wav](audio-to-wav/SKILL.md) | Audio → WAV |
| [audio-trim](audio-trim/SKILL.md) | Trim leading/trailing silence |
| [audio-split](audio-split/SKILL.md) | Split at a timestamp |
| [audio-denoise](audio-denoise/SKILL.md) | Denoise |
| [audio-fade](audio-fade/SKILL.md) | Fade in/out |
| [audio-loudness-normalization](audio-loudness-normalization/SKILL.md) | LUFS loudness normalize |
| [audio-volume-adjust](audio-volume-adjust/SKILL.md) | Fixed dB gain (alternative) |
| [audio-sample-rate-standardize](audio-sample-rate-standardize/SKILL.md) | Standardize to 44100 / 48000 Hz WAV |
| [audio-to-ogg](audio-to-ogg/SKILL.md) | Audio → OGG (BGM) |
| [audio-to-text](audio-to-text/SKILL.md) | Local PCM16 WAV transcription with SenseVoice Small; prefers Vulkan GPU and automatically falls back to CPU |

## Image

AI art and sprite sheets — convert to PNG, clean watermarks, split grids, remove backgrounds, then trim / resize / rename.

```
Source image (AI art / sprite sheet)
    ↓
① image-to-png (optional)
    ↓
② image-inpaint-region — LaMa local inpaint (optional)
    ↓
③ image-sprite-sheet-split — grid → frames (optional)
    ↓
④ image-remove-white-background — flat white / green / magenta
   ·or·  image-remove-background — complex / photo (rembg)
   ·or·  image-region-remove-key-color-app — paint region (manual)
    ↓
⑤ image-trim — borders / transparent padding (optional)
    ↓
⑥ image-resize — target width × height (optional)
    ↓
⑦ file-naming-normalization (optional)
```

| Skill | Purpose |
|-------|---------|
| [image-to-png](image-to-png/SKILL.md) | Image → PNG |
| [image-inpaint-region](image-inpaint-region/SKILL.md) | Local region inpainting with LaMa (IOPaint) |
| [image-sprite-sheet-split](image-sprite-sheet-split/SKILL.md) | Split sprite sheet grid → individual frame PNGs |
| [image-remove-white-background](image-remove-white-background/SKILL.md) | Remove flat white / green / magenta backgrounds (color key; default `global` mode; also `border` / `center` / `both`) |
| [image-remove-background](image-remove-background/SKILL.md) | Remove background / image → transparent PNG (AI matting) |
| [image-region-remove-key-color-app](image-region-remove-key-color-app/SKILL.md) | Manual Gradio app: paint a region, remove key-color only inside that selection |
| [image-trim](image-trim/SKILL.md) | Trim transparent or solid-color borders (preserve aspect ratio by default) |
| [image-resize](image-resize/SKILL.md) | Resize to explicit width × height (fit / fill / exact; ImageMagick) |
| [image-to-text](image-to-text/SKILL.md) | Local image description / OCR with MiniCPM-V 4.6; automatically prefers Vulkan GPU and falls back to CPU |

## Video

Veo / Gemini cutscenes and UI clips — optionally mute or rip audio, upscale / normalize / merge, compress to a size cap, then export Godot-ready OGV. Publish pack for multi-platform release.

```
Source video (Veo / Gemini generated)
    ↓
① video-to-wav — extract audio (optional)
   ·or·  video-remove-audio — mute (optional)
    ↓
② video-to-60fps — RIFE interpolate to 60fps at source res (optional; skip if already 60)
    ↓
③ video-to-4k — upscale to 4K master (optional; keeps fps)
    ↓
④ video-4k-normalization — unify color / fps before merge (optional)
    ↓
⑤ video-merge — random 0.5s xfade (optional)
   ·or·  video-merge-gpu — same, GPU HEVC only (no CPU fallback)
    ↓
⑥ video-compress-to-size — re-encode under max size (optional; GPU preferred)
    ↓
⑦ video-to-ogv — Godot export
```

| Skill | Purpose |
|-------|---------|
| [video-to-wav](video-to-wav/SKILL.md) | Extract audio track → WAV |
| [video-remove-audio](video-remove-audio/SKILL.md) | Remove all audio / mute video (stream copy) |
| [video-to-60fps](video-to-60fps/SKILL.md) | Interpolate → 60fps at source resolution (Video2X RIFE; skip if already 60) |
| [video-to-4k](video-to-4k/SKILL.md) | Upscale → unified 4K H.265 Main10 master, source fps kept (Video2X + FFmpeg) |
| [video-4k-normalization](video-4k-normalization/SKILL.md) | Normalize mixed clips → merge-safe 4K60 Main10 BT.709 SDR (FFmpeg; HDR tone-mapped) |
| [video-merge](video-merge/SKILL.md) | Merge folder of clips → one MP4 with random 0.5s xfade transitions (CPU `libx265`) |
| [video-merge-gpu](video-merge-gpu/SKILL.md) | Same merge, GPU HEVC only (`hevc_nvenc` / `hevc_amf` / `hevc_qsv`; no CPU fallback) |
| [video-compress-to-size](video-compress-to-size/SKILL.md) | Re-encode under a max file size (GPU VBR preferred; CPU two-pass fallback) |
| [video-to-ogv](video-to-ogv/SKILL.md) | Video → OGV |
| [video-publish](video-publish/SKILL.md) | Materials → multi-platform publish pack (Zhihu / Reddit / covers / 8 platforms) |

## Storyboard

Video production pipeline: write bilingual narration, generate per-shot AI video first, then VO, then mux and merge into a final film.

```
Materials / copy / images
    ↓
① storyboard — markdown (CN+EN narration, video prompts, cover)
    ├─ preview (optional)
    │     ↓
    │  storyboard-shot-to-html — one shot → fullscreen HTML motion sketch
    │
    ├─ video branch
    │     ↓
    │  ② Generate AI video (external; from prompts)
    │     ↓
    │  ③ video-remove-audio — mute (drop source track before VO mux)
    │     ↓
    │  ④ video-to-60fps — RIFE interpolate to 60fps at source res (optional; skip if already 60)
    │     ↓
    │  ⑤ video-to-4k → Video/
    │     ↓
    │  ⑥ video-4k-normalization (optional)
    │
    └─ audio branch
          ↓
       ⑦ storyboard-tts → Chinese/ + English/ WAVs (0.4 s edge pad included)
          ↓
       ⑧ audio-loudness-normalization
    ↓
⑨ storyboard-av-mix — mux Video/ + Chinese|English/ → Video-Chinese/ + Video-English/
    ↓
⑩ video-merge ·or· video-merge-gpu → final film
    ↓
⑪ video-compress-to-size — re-encode under max size (optional)
    ↓
⑫ video-publish — platform copy / covers
```

| Skill | Purpose |
|-------|---------|
| [storyboard](storyboard/SKILL.md) | Materials → shot-by-shot storyboard (CN+EN narration, video prompts, cover) |
| [storyboard-shot-to-html](storyboard-shot-to-html/SKILL.md) | One shot (prompt + VO) → fullscreen HTML CSS animation preview (Space to play) |
| [storyboard-tts](storyboard-tts/SKILL.md) | Storyboard.md → bilingual VO WAVs (IndexTTS2 batch; Chinese/ + English/; 0.4 s edge pad) |
| [storyboard-av-mix](storyboard-av-mix/SKILL.md) | Video/ + Chinese/ + English/ → Video-Chinese/ + Video-English/ (retime to VO) |

## Other

| Skill | Purpose                                     |
|-------|---------------------------------------------|
| [file-naming-normalization](file-naming-normalization/SKILL.md) | Filename → kebab-case                       |
| [git-commit-message](git-commit-message/SKILL.md) | Commit message                              |
