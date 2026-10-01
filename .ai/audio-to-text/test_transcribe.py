"""Tests for transcribe.py."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import transcribe  # noqa: E402

REPO_ROOT = transcribe.find_repo_root(SCRIPT_DIR)
assert REPO_ROOT is not None
PYTHON = REPO_ROOT / ".dependency" / "python" / "python.exe"
SCRIPT = SCRIPT_DIR / "transcribe.py"
SAMPLE = REPO_ROOT / ".ai" / "test" / "audio" / "han.wav"


class TranscribeTest(unittest.TestCase):
    def test_configure_utf8_stdio(self) -> None:
        transcribe.configure_utf8_stdio()
        self.assertEqual(sys.stdout.encoding.lower(), "utf-8")

    def test_rejects_non_wav(self) -> None:
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "audio.mp3"
            path.write_bytes(b"not audio")
            with self.assertRaisesRegex(ValueError, "WAV input"):
                transcribe.resolve_audio(str(path))

    def test_gpu_empty_output_falls_back_to_cpu(self) -> None:
        gpu_empty = subprocess.CompletedProcess([], 0, "", "")
        cpu_success = subprocess.CompletedProcess([], 0, "CPU text", "")
        with patch.object(transcribe, "probe_vulkan", return_value=(True, "Vulkan0: GPU")), \
                patch.object(transcribe, "run_backend", side_effect=[gpu_empty, cpu_success]):
            result = transcribe.run_transcription(SCRIPT, SCRIPT, SCRIPT, SCRIPT, SCRIPT, SCRIPT)
        self.assertEqual(result, "CPU text")

    def test_gpu_probe_and_inference_use_their_respective_runtimes(self) -> None:
        gpu_runtime = Path("sensevoice-gpu")
        probe_runtime = Path("llama-vulkan-probe")
        gpu_success = subprocess.CompletedProcess([], 0, "GPU text", "")
        with patch.object(transcribe, "probe_vulkan", return_value=(True, "Vulkan0: GPU")) as probe, \
                patch.object(transcribe, "run_backend", return_value=gpu_success) as run_backend:
            result = transcribe.run_transcription(SCRIPT, gpu_runtime, probe_runtime,
                                                  SCRIPT, SCRIPT, SCRIPT)
        self.assertEqual(result, "GPU text")
        probe.assert_called_once_with(probe_runtime)
        run_backend.assert_called_once_with(gpu_runtime, "vulkan", SCRIPT, SCRIPT, SCRIPT)

    def test_gpu_and_cpu_errors_are_both_reported(self) -> None:
        gpu_failure = subprocess.CompletedProcess([], 1, "", "GPU broke")
        cpu_failure = subprocess.CompletedProcess([], 1, "", "CPU broke")
        with patch.object(transcribe, "probe_vulkan", return_value=(True, "Vulkan0: GPU")), \
                patch.object(transcribe, "run_backend", side_effect=[gpu_failure, cpu_failure]):
            with self.assertRaisesRegex(RuntimeError, r"GPU: GPU broke; CPU: CPU broke"):
                transcribe.run_transcription(SCRIPT, SCRIPT, SCRIPT, SCRIPT, SCRIPT, SCRIPT)

    def test_native_transcription(self) -> None:
        if not SAMPLE.is_file():
            self.skipTest("sample WAV is missing")
        result = subprocess.run([str(PYTHON), str(SCRIPT), "--audio", str(SAMPLE)], capture_output=True,
                                text=True, encoding="utf-8", errors="replace", cwd=str(REPO_ROOT))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("哪吒", result.stdout)

if __name__ == "__main__":
    raise SystemExit(unittest.main())
