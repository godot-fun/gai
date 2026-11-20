#!/usr/bin/env python3
"""Tests for mix.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
AI_ROOT = SCRIPT_DIR.parent
if str(AI_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_ROOT))

import mix  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
MIX_SCRIPT = SCRIPT_DIR / "mix.py"


class ListByStemTest(unittest.TestCase):
    def test_lists_matching_extensions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "01.mp4").write_bytes(b"x")
            (root / "02.mkv").write_bytes(b"x")
            (root / "notes.txt").write_bytes(b"x")
            found = mix.list_by_stem(root, mix.VIDEO_EXTENSIONS)
            self.assertEqual(sorted(found.keys()), ["01", "02"])
            self.assertEqual(found["01"].suffix, ".mp4")

    def test_missing_folder_returns_empty(self) -> None:
        self.assertEqual(mix.list_by_stem(Path("/no-such-folder"), mix.VIDEO_EXTENSIONS), {})


class BuildJobsTest(unittest.TestCase):
    def test_builds_bilingual_jobs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "vo"
            clips = Path(tmp) / "Video"
            (root / "Chinese").mkdir(parents=True)
            (root / "English").mkdir()
            (clips / "Chinese").mkdir(parents=True)
            (clips / "English").mkdir()
            (clips / "Chinese" / "01.mp4").write_bytes(b"zh-video")
            (clips / "English" / "01.mp4").write_bytes(b"en-video")
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (root / "English" / "01.wav").write_bytes(b"a")

            jobs = mix.build_jobs(root, "both", clips)
            self.assertEqual(len(jobs), 2)
            langs = {job.lang for job in jobs}
            self.assertEqual(langs, {"chinese", "english"})
            by_lang = {job.lang: job for job in jobs}
            self.assertEqual(by_lang["chinese"].video.parent.name, "Chinese")
            self.assertEqual(by_lang["english"].video.parent.name, "English")
            self.assertEqual(
                by_lang["chinese"].output.parent,
                (root / "Video" / "Chinese").resolve(),
            )
            pass

    def test_single_language_builds_only_that_language(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "vo"
            clips = Path(tmp) / "Video"
            (root / "Chinese").mkdir(parents=True)
            (root / "English").mkdir()
            (clips / "Chinese").mkdir(parents=True)
            (clips / "English").mkdir()
            (clips / "Chinese" / "01.mp4").write_bytes(b"v")
            (clips / "English" / "01.mp4").write_bytes(b"v")
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (root / "English" / "01.wav").write_bytes(b"a")

            jobs = mix.build_jobs(root, "english", clips)
            self.assertEqual([job.lang for job in jobs], ["english"])
            pass

    def test_custom_output_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Audio"
            clips = Path(tmp) / "Video"
            output = Path(tmp) / "Output"
            (root / "Chinese").mkdir(parents=True)
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (clips / "Chinese").mkdir(parents=True)
            (clips / "Chinese" / "01.mp4").write_bytes(b"v")

            jobs = mix.build_jobs(root, "chinese", clips, output)
            self.assertEqual(jobs[0].output, output.resolve() / "Chinese" / "01.mp4")

    def test_legacy_flat_video_layout_is_supported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Audio"
            clips = Path(tmp) / "Video"
            (root / "Chinese").mkdir(parents=True)
            (root / "English").mkdir()
            clips.mkdir()
            (clips / "01.mp4").write_bytes(b"v")
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (root / "English" / "01.wav").write_bytes(b"a")

            jobs = mix.build_jobs(root, "both", clips)
            self.assertEqual(len(jobs), 2)
            self.assertEqual({job.video for job in jobs}, {(clips / "01.mp4").resolve()})

    def test_language_layout_does_not_cross_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Audio"
            clips = Path(tmp) / "Video"
            (root / "Chinese").mkdir(parents=True)
            (root / "English").mkdir()
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (root / "English" / "01.wav").write_bytes(b"a")
            (clips / "Chinese").mkdir(parents=True)
            (clips / "Chinese" / "01.mp4").write_bytes(b"v")

            jobs = mix.build_jobs(root, "both", clips)
            self.assertEqual([job.lang for job in jobs], ["chinese"])

    def test_rejects_output_that_overwrites_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Audio"
            clips = root / "Video"
            (root / "Chinese").mkdir(parents=True)
            (root / "Chinese" / "01.wav").write_bytes(b"a")
            (clips / "Chinese").mkdir(parents=True)
            (clips / "Chinese" / "01.mp4").write_bytes(b"v")

            with self.assertRaises(mix.MixError):
                mix.build_jobs(root, "chinese", clips)

    def test_missing_clip_folder_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(mix.MixError):
                mix.build_jobs(Path(tmp), "both", Path(tmp) / "Video")
            pass


class RequireDirTest(unittest.TestCase):
    def test_resolves_existing_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(mix.require_dir(Path(tmp), "Audio dir"), Path(tmp).resolve())
            pass

    def test_rejects_missing_dir_with_label(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(mix.MixError) as ctx:
                mix.require_dir(Path(tmp) / "nope", "Video dir")
            self.assertIn("Video dir not found", str(ctx.exception))
            pass


class VideoEncodeArgsTest(unittest.TestCase):
    def test_hevc_main10_preserves_hdr_params(self) -> None:
        probe = mix.VideoProbe(
            codec_name="hevc",
            profile="Main 10",
            pix_fmt="yuv420p10le",
            color_range="tv",
            color_space="bt2020nc",
            color_transfer="smpte2084",
            color_primaries="bt2020",
            bit_rate=40_000_000,
            mastering={
                "red_x": "34000/50000",
                "red_y": "16000/50000",
                "green_x": "13250/50000",
                "green_y": "34500/50000",
                "blue_x": "7500/50000",
                "blue_y": "3000/50000",
                "white_point_x": "15635/50000",
                "white_point_y": "16450/50000",
                "max_luminance": "10000000/10000",
                "min_luminance": "50/10000",
            },
            cll={"max_content": 1000, "max_average": 400},
        )
        args = mix.video_encode_args(probe)
        joined = " ".join(args)
        self.assertIn("libx265", joined)
        self.assertIn("main10", joined)
        self.assertIn("master-display=", joined)
        self.assertIn("max-cll=1000,400", joined)
        self.assertIn("-b:v 40000000", joined)
        self.assertIn("-preset slow", joined)

    def test_h264_fallback(self) -> None:
        probe = mix.VideoProbe(
            codec_name="h264",
            profile="High",
            pix_fmt="yuv420p",
            color_range="",
            color_space="",
            color_transfer="",
            color_primaries="",
            bit_rate=None,
        )
        args = mix.video_encode_args(probe)
        joined = " ".join(args)
        self.assertIn("-c:v libx264", joined)
        self.assertIn("-crf 14", joined)
        self.assertIn("-preset slow", joined)


class MasterDisplayTest(unittest.TestCase):
    def test_formats_x265_master_display(self) -> None:
        text = mix._master_display_x265(
            {
                "red_x": "34000/50000",
                "red_y": "16000/50000",
                "green_x": "13250/50000",
                "green_y": "34500/50000",
                "blue_x": "7500/50000",
                "blue_y": "3000/50000",
                "white_point_x": "15635/50000",
                "white_point_y": "16450/50000",
                "max_luminance": "10000000/10000",
                "min_luminance": "50/10000",
            }
        )
        self.assertIn("G(13250,34500)", text)
        self.assertIn("WP(15635,16450)", text)


class MixCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(PYTHON_BIN), str(MIX_SCRIPT), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=str(REPO_ROOT),
        )

    def test_help(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--audio AUDIO", result.stdout)
        self.assertIn("--video VIDEO", result.stdout)
        self.assertIn("--output OUTPUT", result.stdout)
        self.assertIn("--lang", result.stdout)
        self.assertNotIn("Legacy", result.stdout)
        pass

    def test_no_args_requires_both_flags(self) -> None:
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--audio", result.stderr)
        self.assertIn("--video", result.stderr)
        pass

    def test_missing_video_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--audio", tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("--video", result.stderr)
            pass

    def test_missing_audio_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--video", tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("--audio", result.stderr)
            pass

    def test_positional_path_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--audio", tmp, "--video", tmp, tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unrecognized arguments", result.stderr)
            pass

    def test_audio_dir_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--audio", str(Path(tmp) / "nope"), "--video", tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Audio dir not found", result.stderr)
            pass

    def test_video_dir_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_cli("--audio", tmp, "--video", str(Path(tmp) / "nope"))
            self.assertEqual(result.returncode, 1)
            self.assertIn("Video dir not found", result.stderr)
            pass

    def test_paths_reach_job_build(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            audio_dir = Path(tmp) / "vo"
            (audio_dir / "Chinese").mkdir(parents=True)
            (audio_dir / "English").mkdir()
            clips = Path(tmp) / "Video"
            clips.mkdir()
            # Both dirs resolve, then job build fails on "no video files".
            result = self.run_cli("--audio", str(audio_dir), "--video", str(clips))
            self.assertEqual(result.returncode, 1)
            self.assertIn("No video files in", result.stderr)
            self.assertIn(f"Audio: {audio_dir.resolve()}", result.stdout)
            self.assertIn(f"Video: {clips.resolve()}", result.stdout)
            pass


if __name__ == "__main__":
    unittest.main()
