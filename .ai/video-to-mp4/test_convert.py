#!/usr/bin/env python3
"""Tests for video-to-mp4 convert.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AI_ROOT = SCRIPT_DIR.parent
sys.path[:0] = [str(SCRIPT_DIR), str(AI_ROOT)]

import convert  # noqa: E402
from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
CONVERT_SCRIPT = SCRIPT_DIR / "convert.py"
SAMPLE_VIDEO = REPO_ROOT / ".ai/test/video/opening.mp4"


class ConvertLogicTest(unittest.TestCase):
    def test_stream_copy_compatible_mp4(self) -> None:
        probe = {"video": {"codec": "h264", "pix_fmt": "yuv420p"}, "audio": {"codec": "aac"}}
        self.assertTrue(convert.can_stream_copy(Path("clip.mp4"), probe))
        self.assertFalse(convert.can_stream_copy(Path("clip.mkv"), probe))
        self.assertFalse(convert.can_stream_copy(Path("clip.mp4"), probe, True))

    def test_encode_args_preserve_size_and_fps(self) -> None:
        probe = {"video": {"codec": "vp9"}, "audio": {"codec": "opus"}}
        args = convert.build_ffmpeg_args(Path("ffmpeg"), Path("in.webm"), Path("out.mp4"), probe, 18, "slow", "192k", False)
        self.assertIn("libx264", args)
        self.assertIn("yuv420p", args)
        self.assertIn("+faststart", args)
        self.assertNotIn("-vf", args)
        self.assertNotIn("-r", args)


class ConvertCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(PYTHON_BIN), str(CONVERT_SCRIPT), *args], capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(REPO_ROOT))

    def test_help(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--video", result.stdout)
        self.assertIn("--force-encode", result.stdout)

    def test_rejects_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--video", tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn("directories are not supported", result.stderr)

    def test_convert_single_file(self) -> None:
        if not SAMPLE_VIDEO.is_file():
            self.skipTest("sample video missing")
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / SAMPLE_VIDEO.name
            source.write_bytes(SAMPLE_VIDEO.read_bytes())
            result = self.run_cli("--video", str(source))
            self.assertEqual(result.returncode, 0, result.stderr)
            output = source.parent / convert.DEFAULT_OUTPUT_SUBDIR / source.name
            self.assertTrue(output.is_file())
            ffmpeg = resolve_ffmpeg(CONVERT_SCRIPT)
            probe = convert.probe_streams(resolve_ffprobe(ffmpeg), output)
            self.assertEqual(probe["video"].get("codec"), "h264")
            self.assertIn(probe["video"].get("pix_fmt"), {"yuv420p", "yuvj420p"})
            if probe.get("audio"):
                self.assertEqual(probe["audio"].get("codec"), "aac")


if __name__ == "__main__":
    raise SystemExit(unittest.main())
