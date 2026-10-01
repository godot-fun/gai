#!/usr/bin/env python3
"""Run native SenseVoice Small GGUF transcription and print clean text.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python.exe .ai/audio-to-text/transcribe.py --audio path/to/audio.wav
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin, resolve_tool_model_dir  # noqa: E402
from common.output_utils import configure_utf8_stdio  # noqa: E402

CPU_RUNTIME_TOOL = "funasr-llamacpp-cpu"
GPU_RUNTIME_TOOL = "funasr-llamacpp-gpu"
GPU_PROBE_TOOL = "llama-cpp-gpu"
MODEL_TOOL = "sensevoice-small-gguf"
MODEL_NAME = "sensevoice-small-f16.gguf"
VAD_MODEL_NAME = "fsmn-vad.gguf"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe one WAV with native SenseVoice Small GGUF.")
    parser.add_argument("--audio", required=True, help="PCM WAV input.")
    return parser.parse_args()


def manifest_paths(root: Path) -> tuple[Path, Path, Path, Path, Path]:
    model_dir = resolve_tool_model_dir(root, MODEL_TOOL)
    return (resolve_tool_bin(root, CPU_RUNTIME_TOOL),
            resolve_tool_bin(root, GPU_RUNTIME_TOOL),
            resolve_tool_bin(root, GPU_PROBE_TOOL),
            model_dir / MODEL_NAME, model_dir / VAD_MODEL_NAME)


def resolve_audio(raw_path: str) -> Path:
    audio = Path(raw_path).expanduser().resolve()
    if not audio.is_file():
        raise FileNotFoundError(f"Audio file not found: {audio}")
    if audio.suffix.lower() != ".wav":
        raise ValueError("SenseVoice GGUF requires a WAV input")
    try:
        with wave.open(str(audio), "rb") as wav:
            properties = (wav.getframerate(), wav.getnchannels(), wav.getsampwidth(), wav.getcomptype())
    except (EOFError, wave.Error) as exc:
        raise ValueError(f"Invalid WAV file: {audio}") from exc
    if properties[2] != 2 or properties[3] != "NONE":
        raise ValueError("Input must be uncompressed PCM16 WAV")
    return audio


def run_backend(runtime: Path, backend: str, model: Path, vad: Path,
                audio: Path) -> subprocess.CompletedProcess[str]:
    command = [str(runtime), "-m", str(model), "--vad", str(vad), "-a", str(audio), "--backend", backend]
    return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")


def probe_vulkan(runtime: Path) -> tuple[bool, str]:
    """Actively ask the GPU runtime whether it exposes a Vulkan device."""
    try:
        result = subprocess.run([str(runtime), "--list-devices"], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=10)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    output = (result.stdout + "\n" + result.stderr).strip()
    available = result.returncode == 0 and "(none)" not in output.lower() and bool(
        re.search(r"^\s*Vulkan\S*:\s*.+$", output, re.MULTILINE | re.IGNORECASE))
    return available, output or f"device probe exited with code {result.returncode}"


def result_error(result: subprocess.CompletedProcess[str], empty_message: str) -> str:
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        return detail or f"process exited with code {result.returncode}"
    return empty_message


def run_transcription(cpu_runtime: Path, vulkan_runtime: Path, gpu_probe_runtime: Path,
                      model: Path, vad: Path, audio: Path) -> str:
    for required in (cpu_runtime, model, vad):
        if not required.is_file():
            raise FileNotFoundError(f"Required dependency is missing: {required}")
    gpu_error: str | None = None
    gpu_available, probe_detail = probe_vulkan(gpu_probe_runtime)
    if gpu_available:
        gpu_result = run_backend(vulkan_runtime, "vulkan", model, vad, audio)
        transcript = gpu_result.stdout.strip() if gpu_result.returncode == 0 else ""
        if transcript:
            return transcript
        gpu_error = result_error(gpu_result, "GPU returned no transcription")
    else:
        gpu_error = f"Vulkan device probe failed: {probe_detail}"
    cpu_result = run_backend(cpu_runtime, "cpu", model, vad, audio)
    transcript = cpu_result.stdout.strip() if cpu_result.returncode == 0 else ""
    if transcript:
        return transcript
    cpu_error = result_error(cpu_result, "CPU returned no transcription")
    if gpu_error is not None:
        raise RuntimeError(f"SenseVoice inference failed (GPU: {gpu_error}; CPU: {cpu_error})")
    raise RuntimeError(f"SenseVoice CPU inference failed: {cpu_error}")


def main() -> int:
    configure_utf8_stdio()
    try:
        args = parse_args()
        root = find_repo_root(Path(__file__).parent)
        if root is None:
            raise RuntimeError("Repository root containing .dependency/manifest.json was not found")
        cpu_runtime, vulkan_runtime, gpu_probe_runtime, model, vad = manifest_paths(root)
        audio = resolve_audio(args.audio)
        transcript = run_transcription(cpu_runtime, vulkan_runtime, gpu_probe_runtime, model, vad, audio)
        print(transcript)
        return 0
    except (FileNotFoundError, KeyError, OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
