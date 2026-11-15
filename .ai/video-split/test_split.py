#!/usr/bin/env python3
"""Tests for video-split split.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AI_ROOT = SCRIPT_DIR.parent
sys.path[:0] = [str(SCRIPT_DIR), str(AI_ROOT)]

import split  # noqa: E402
from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
SPLIT_SCRIPT = SCRIPT_DIR / "split.py"
SAMPLE_VIDEO = REPO_ROOT / ".ai/test/video/opening.mp4"


class SplitLogicTest(unittest.TestCase):
    def test_default_is_half(self) -> None:
        self.assertEqual(split.resolve_split_seconds(10.0, None, None), 5.0)

    def test_seconds_and_percent(self) -> None:
        self.assertEqual(split.resolve_split_seconds(10.0, 3.0, None), 3.0)
        self.assertEqual(split.resolve_split_seconds(10.0, None, 25.0), 2.5)

    def test_invalid_points(self) -> None:
        with self.assertRaises(ValueError):
            split.resolve_split_seconds(10.0, 0.0, None)
        with self.assertRaises(ValueError):
            split.resolve_split_seconds(10.0, 10.0, None)

    def test_output_paths_are_mp4(self) -> None:
        part1, part2 = split.output_paths(Path("out"), Path("clip.webm"))
        self.assertEqual(part1.name, "clip_part1.mp4")
        self.assertEqual(part2.name, "clip_part2.mp4")


class SplitCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(PYTHON_BIN), str(SPLIT_SCRIPT), *args], capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(REPO_ROOT))

    def test_help(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--video", result.stdout)
        self.assertIn("--percent", result.stdout)

    def test_video_not_found(self) -> None:
        result = self.run_cli("--video", "missing-no-such-video.mp4")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Video file not found", result.stderr)

    def test_rejects_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--video", tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn("directories are not supported", result.stderr)

    def test_split_sample_in_half(self) -> None:
        if not SAMPLE_VIDEO.is_file():
            self.skipTest("sample video missing")
        ffmpeg = resolve_ffmpeg(SPLIT_SCRIPT)
        ffprobe = resolve_ffprobe(ffmpeg)
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--video", str(SAMPLE_VIDEO), "--output", tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            part1, part2 = split.output_paths(Path(tmp), SAMPLE_VIDEO)
            self.assertTrue(part1.is_file())
            self.assertTrue(part2.is_file())
            source_duration = split.get_duration(ffprobe, SAMPLE_VIDEO)
            duration1 = split.get_duration(ffprobe, part1)
            duration2 = split.get_duration(ffprobe, part2)
            self.assertAlmostEqual(duration1, source_duration / 2, delta=0.15)
            self.assertAlmostEqual(duration2, source_duration / 2, delta=0.15)
            self.assertAlmostEqual(duration1 + duration2, source_duration, delta=0.2)
            probe1 = subprocess.run(
                [str(ffprobe), "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,pix_fmt", "-of", "default=noprint_wrappers=1", str(part1)],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
            )
            self.assertEqual(probe1.returncode, 0, probe1.stderr)
            self.assertIn("codec_name=h264", probe1.stdout)
            self.assertIn("pix_fmt=yuv420p", probe1.stdout)


if __name__ == "__main__":
    raise SystemExit(unittest.main())
