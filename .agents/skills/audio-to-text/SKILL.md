---
name: audio-to-text
description: Transcribes a single PCM16 WAV file to plain UTF-8 text locally through a standard-library Python wrapper around native SenseVoice Small F16 GGUF FunASR llama.cpp runtimes, preferring cross-vendor Vulkan GPU acceleration and automatically falling back to CPU, with built-in FSMN-VAD. Use when the user wants offline speech-to-text, audio transcription, ASR, or spoken-content extraction in Mandarin, Cantonese, English, Japanese, or Korean.
---

# Audio to Text

Run the bundled standard-library Python wrapper, which validates input, invokes native `llama-funasr-sensevoice`, removes runtime logs, and prints only UTF-8 transcription text. Prefer the Vulkan runtime for NVIDIA, AMD, or Intel GPUs and automatically retry with CPU when Vulkan is unavailable. Do not use CUDA, PyTorch, FunASR Python, or a remote API.

## Rules

Read and follow [skill-dependency-manager](../skill-dependency-manager.md) before running commands.

- Run `.ai/audio-to-text/transcribe.py` through the default `python` manifest entry. Do not invoke the native binary by hand.
- Let the wrapper try `funasr-llamacpp-gpu` first with the Vulkan backend and fall back to `funasr-llamacpp-cpu`. Do not use CUDA, FunASR Python, PyTorch, ONNX, or host tools.
- Load `sensevoice-small-f16.gguf` and `fsmn-vad.gguf` only from the `sensevoice-small-gguf` manifest model directory.
- Process exactly one audio file per invocation. Repeat the command for multiple files.
- Require uncompressed PCM16 WAV input. The current native runtime accepts common sample rates and channel layouts. For other containers, first chain `audio-to-wav`.
- Always pass `--vad` for long-audio segmentation.
- Produce plain UTF-8 transcription text only.
- Never overwrite or modify the source audio.

## Usage

Plain transcription:

```powershell
.dependency/python/python.exe .ai/audio-to-text/transcribe.py --audio C:\path\speech.wav
```

Do not write a transcript file. Return the text printed to stdout. See [cli/audio-to-text.md](../../../cli/audio-to-text.md) for tests and copy-paste commands.

Use `--cpu` only when the user explicitly requests CPU or Vulkan troubleshooting requires bypassing GPU acceleration.

## Report

Return only the transcript. For long audio, summarize instead of dumping the entire transcript unless asked.

## Troubleshooting

- Invalid WAV: convert to uncompressed PCM16 WAV before retrying.
- Vulkan fallback: update the GPU driver and confirm it exposes a Vulkan device; use `--cpu` to bypass Vulkan deliberately.
- Slow inference: F16 prioritizes fidelity and uses more memory than Q8.
- Missing runtime: verify both `.dependency/funasr-llamacpp-gpu/llama-funasr-sensevoice.exe` and the CPU runtime exist.
- Missing model: verify both GGUF files exist under `.dependency/sensevoice-small-gguf/model/`.
