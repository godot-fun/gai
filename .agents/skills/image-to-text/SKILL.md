---
name: image-to-text
description: >-
  Converts one image into a faithful text description or OCR with the local
  Qwen3.8-27B Q4_K_M GGUF model through llama.cpp, automatically preferring an available
  Vulkan GPU and falling back to CPU. Use when the user asks to
  describe, caption, transcribe, inspect, or extract visible details and text
  from PNG, JPEG, WebP, GIF, BMP, or TIFF images without a GPU or remote vision API.
---

# Image to Text

Run the `ggml-org/Qwen3.8-27B-GGUF` Q4_K_M model locally with llama.cpp. Do not send images to remote APIs.

## Rules

Read and follow [dependency-manager](../dependency-manager.md) before running commands.

- Run `.ai/image-to-text/image_to_text.py` through the default `python` manifest entry only.
- Load the language model and multimodal projector only from `.dependency/qwen3.8-27b/model`.
- Before inference, check the `llama-cpp-gpu` runtime with `--list-devices`. Prefer it when a Vulkan device is reported; otherwise use `llama-cpp-cpu`.
- Use `--gpu` or `-GPU` to require GPU inference and fail when unavailable.
- Use `--cpu` to bypass detection and force CPU inference for troubleshooting or comparison.
- Preserve observable facts and clearly distinguish uncertainty from fact.
- Pass exactly one image file to `--image` per invocation.

## Usage

```powershell
.dependency/python/python.exe .ai/image-to-text/image_to_text.py --image C:\path\photo.png
```

```powershell
.dependency/python/python.exe .ai/image-to-text/image_to_text.py --image C:\path\photo.png -GPU
```

```powershell
.dependency/python/python.exe .ai/image-to-text/image_to_text.py --image C:\path\photo.png --cpu
```

Use `--output description.md` to also save UTF-8 text. See [cli/image-to-text.md](../../../cli/image-to-text.md) for copy-paste commands.

## Output guidance

- General description: mention scene, subjects, actions, composition, colors, and legible text.
- OCR: preserve reading order and line breaks where practical; mark uncertain characters with `[unclear]`.
- Accessibility alt text: be concise and omit decorative speculation.
- Structured extraction: request JSON explicitly and validate it before presenting it as machine-readable.
- Never identify a real person from appearance alone or infer sensitive traits not explicitly visible as text.

## Troubleshooting

- Missing CPU runtime: verify `.dependency/llama-cpp-cpu/llama-mtmd-cli.exe` exists.
- GPU unavailable: verify `.dependency/llama-cpp-gpu/llama-mtmd-cli.exe` exists and `--list-devices` reports a Vulkan device. Update the graphics driver if necessary.
- Missing model: verify `Qwen3.8-27B-Q4_K_M.gguf` and `mmproj-Qwen3.8-27B-BF16.gguf` exist under `.dependency/qwen3.8-27b/model`.
- Out of memory: close other applications, reduce context, use a smaller image, or run on CPU; Q4_K_M plus the vision projector needs roughly 22GB before runtime overhead.
- Slow inference: CPU speed, core count, memory bandwidth, and image resolution directly affect latency.
