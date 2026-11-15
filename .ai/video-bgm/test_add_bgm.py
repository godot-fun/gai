#!/usr/bin/env python3
"""Tests for add_bgm.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AI_ROOT = SCRIPT_DIR.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
if str(AI_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_ROOT))

import add_bgm  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.output_utils import resolve_output_path  # noqa: E402
from common.video_utils import video_output_name  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
FFMPEG_BIN = resolve_tool_bin(REPO_ROOT, "ffmpeg")
ADD_BGM_SCRIPT = SCRIPT_DIR / "add_bgm.py"


class VideoBgmLogicTest(unittest.TestCase):
    def test_crossfade_is_bounded_by_shortest_track(self) -> None:
        self.assertEqual(add_bgm.crossfade_duration([4.0, 8.0]), 1.0)
        self.assertEqual(add_bgm.crossfade_duration([0.5, 8.0]), 0.25)
        self.assertEqual(add_bgm.crossfade_duration([4.0]), 0.0)

    def test_mix_stream_copies_video(self) -> None:
        cmd = add_bgm.build_mix_args(Path("ffmpeg"), Path("in.mp4"), Path("bed.wav"), Path("out.mp4"), 10.0, True)
        self.assertIn("copy", cmd)
        self.assertIn("amix=inputs=2", " ".join(cmd))
        self.assertIn("-stream_loop", cmd)

    def test_default_output_path(self) -> None:
        source = Path("/tmp/clip.mp4")
        out = resolve_output_path("", source, add_bgm.DEFAULT_OUTPUT_SUBDIR, video_output_name(source))
        self.assertEqual(out, source.parent / "video-bgm" / "clip.mp4")

    def test_audio_folder_uses_natural_filename_order(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("10_end.wav", "2_middle.mp3", "1_intro.ogg"):
                (root / name).touch()
            (root / "notes.txt").touch()
            paths = add_bgm.resolve_audio_input(str(root))
            self.assertIsNotNone(paths)
            self.assertEqual([path.name for path in paths or []], ["1_intro.ogg", "2_middle.mp3", "10_end.wav"])

    def test_empty_audio_folder_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(add_bgm.resolve_audio_input(tmp))

    def test_audio_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "bgm.wav"
            audio.touch()
            self.assertIsNone(add_bgm.resolve_audio_input(str(audio)))


class VideoBgmCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(PYTHON_BIN), str(ADD_BGM_SCRIPT), *args], capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(REPO_ROOT))

    def test_help_has_only_simple_parameters(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--video", result.stdout)
        self.assertIn("--audio", result.stdout)
        self.assertIn("--output", result.stdout)
        self.assertNotIn("--volume", result.stdout)
        self.assertNotIn("--fade", result.stdout)
        self.assertNotIn("--loop", result.stdout)

    def test_rejects_missing_audio(self) -> None:
        result = self.run_cli("--video", "missing.mp4", "--audio", "missing.mp3")
        self.assertEqual(result.returncode, 1)

    def test_end_to_end_short_bgm_loops(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            video = root / "input.mp4"
            audio_dir = root / "music"
            audio_dir.mkdir()
            audio = audio_dir / "bgm.wav"
            output = root / "output.mp4"
            subprocess.run([str(FFMPEG_BIN), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=160x90:r=24:d=2", "-f", "lavfi", "-i", "sine=frequency=220:duration=2", "-c:v", "libx264", "-c:a", "aac", "-shortest", str(video)], check=True)
            subprocess.run([str(FFMPEG_BIN), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=880:duration=0.4", "-c:a", "pcm_s16le", str(audio)], check=True)
            result = self.run_cli("--video", str(video), "--audio", str(audio_dir), "--output", str(output))
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertTrue(output.is_file())
            self.assertGreater(output.stat().st_size, 0)

    def test_end_to_end_audio_folder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            video = root / "input.mp4"
            audio_dir = root / "music"
            audio_dir.mkdir()
            output = root / "output.mp4"
            subprocess.run([str(FFMPEG_BIN), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=160x90:r=24:d=2", "-c:v", "libx264", str(video)], check=True)
            for index, frequency in enumerate((440, 880), 1):
                subprocess.run([str(FFMPEG_BIN), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", f"sine=frequency={frequency}:duration=0.5", "-c:a", "pcm_s16le", str(audio_dir / f"{index:02d}.wav")], check=True)
            result = self.run_cli("--video", str(video), "--audio", str(audio_dir), "--output", str(output))
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertTrue(output.is_file())


if __name__ == "__main__":
    raise SystemExit(unittest.main())
