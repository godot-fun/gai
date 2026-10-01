"""Describe images with MiniCPM-V 4.6 GGUF, preferring an available GPU.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python.exe .ai/image-to-text/image_to_text.py --images image.png
    .dependency/python/python.exe .ai/image-to-text/image_to_text.py --images before.png after.png --prompt "Compare the images."
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin, resolve_tool_model_dir  # noqa: E402
from common.image_utils import resolve_image_file  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402

CPU_RUNTIME_TOOL = "llama-cpp-cpu"
GPU_RUNTIME_TOOL = "llama-cpp-gpu"
MODEL_TOOL = "minicpm-v-4.6"
MODEL_NAME = "MiniCPM-V-4_6-Q4_K_M.gguf"
MMPROJ_NAME = "mmproj-model-f16.gguf"
DEFAULT_PROMPT = ("Describe the image accurately and comprehensively. Include visible subjects, actions, "
                  "setting, composition, notable colors, and legible text. Clearly mark uncertainty and "
                  "do not invent details that are not visible.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert images to text with MiniCPM-V 4.6 locally.")
    parser.add_argument("--images", "--image", dest="images", nargs="+", required=True,
                        help="One or more input images.")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Instruction sent with the images.")
    parser.add_argument("--output", default="", help="Optional UTF-8 output text file; default: stdout only. "
                        + format_default_output_help("image-to-text", output_name_label="source-stem.txt"))
    return parser.parse_args()


def resolve_images(raw_paths: list[str]) -> list[Path] | None:
    paths: list[Path] = []
    for raw_path in raw_paths:
        path = resolve_image_file(raw_path)
        if path is None:
            return None
        if "," in str(path):
            print(f"Image path cannot contain a comma: {path}", file=sys.stderr)
            return None
        paths.append(path)
    return paths


def clean_model_output(output: str) -> str:
    """Remove an optional hidden-reasoning block emitted before the final answer."""
    return re.sub(r"^\s*<think>.*?</think>\s*", "", output, count=1, flags=re.DOTALL).strip()


def acceleration_args(use_gpu: bool) -> list[str]:
    """Return llama.cpp arguments for the requested compute device."""
    return ["-ngl", "999"] if use_gpu else ["-ngl", "0", "--no-mmproj-offload"]


def gpu_is_available(executable: Path) -> tuple[bool, str]:
    """Return whether the Vulkan llama.cpp build reports a usable GPU device."""
    try:
        result = subprocess.run([str(executable), "--list-devices"], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=10)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    output = result.stdout + "\n" + result.stderr
    available = result.returncode == 0 and "(none)" not in output.lower() and bool(
        re.search(r"^\s*Vulkan\S*:\s+.+$", output, re.MULTILINE | re.IGNORECASE))
    return available, output.strip() or f"device probe exited with code {result.returncode}"


def describe_images(executable: Path, model: Path, mmproj: Path, prompt: str,
                    image_paths: list[Path], use_gpu: bool = False) -> str:
    for required in (executable, model, mmproj):
        if not required.is_file():
            raise FileNotFoundError(f"Required local dependency is missing: {required}")
    command = [str(executable), "-m", str(model), "--mmproj", str(mmproj), "--image",
               ",".join(str(path) for path in image_paths), "-p", prompt]
    command.extend(acceleration_args(use_gpu))
    command.extend(["-c", "4096", "-n", "1024", "--temp", "0"])
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"MiniCPM-V inference failed{': ' + detail if detail else ''}")
    output = clean_model_output(result.stdout)
    if not output:
        raise RuntimeError("MiniCPM-V returned no text")
    return output


def infer_with_fallback(cpu_runtime: Path, gpu_runtime: Path, model: Path, mmproj: Path,
                        prompt: str, image_paths: list[Path]) -> str:
    gpu_error: str | None = None
    available, probe_detail = gpu_is_available(gpu_runtime)
    if available:
        try:
            return describe_images(gpu_runtime, model, mmproj, prompt, image_paths, True)
        except (OSError, RuntimeError) as exc:
            gpu_error = str(exc)
    else:
        gpu_error = f"Vulkan device probe failed: {probe_detail}"
    try:
        return describe_images(cpu_runtime, model, mmproj, prompt, image_paths, False)
    except (OSError, RuntimeError) as exc:
        if gpu_error is not None:
            raise RuntimeError(f"MiniCPM-V inference failed (GPU: {gpu_error}; CPU: {exc})") from exc
        raise


def main() -> int:
    configure_utf8_stdio()
    args = parse_args()
    image_paths = resolve_images(args.images)
    if image_paths is None:
        return 1
    try:
        root = find_repo_root(Path(__file__).parent)
        if root is None:
            raise RuntimeError("Repository root containing .dependency/manifest.json was not found")
        cpu_runtime = resolve_tool_bin(root, CPU_RUNTIME_TOOL)
        gpu_runtime = resolve_tool_bin(root, GPU_RUNTIME_TOOL)
        model_dir = resolve_tool_model_dir(root, MODEL_TOOL)
        description = infer_with_fallback(cpu_runtime, gpu_runtime, model_dir / MODEL_NAME,
                                          model_dir / MMPROJ_NAME, args.prompt, image_paths)
        if args.output:
            output = resolve_output_path(args.output, image_paths[0], "image-to-text",
                                         f"{image_paths[0].stem}.txt")
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(description + "\n", encoding="utf-8")
        print(description)
        return 0
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
