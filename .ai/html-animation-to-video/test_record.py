#!/usr/bin/env python3
"""Unit tests for record.py; no browser, no screen, and no FFmpeg process is used."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import record  # noqa: E402

CAPTURE = record.Capture(x=100, y=200, width=3840, height=2160)
MONITOR = record.Monitor(index=1, x=0, y=0, width=3840, height=2160)


class ServerUrlTest(unittest.TestCase):
    def test_prefers_env(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            web = Path(temporary)
            (web / ".env").write_text("HOST = 127.0.0.2\nPORT = 4000\n", encoding="utf-8")
            (web / ".env.example").write_text("HOST = 127.0.0.3\nPORT = 5000\n", encoding="utf-8")
            self.assertEqual(record.resolve_server_url(web), "http://127.0.0.2:4000")

    def test_falls_back_to_example_per_field(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            web = Path(temporary)
            (web / ".env").write_text("HOST = 127.0.0.2\n", encoding="utf-8")
            (web / ".env.example").write_text("HOST = 127.0.0.3\nPORT = 5000\n", encoding="utf-8")
            self.assertEqual(record.resolve_server_url(web), "http://127.0.0.2:5000")

    def test_requires_port(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(record.RecordError, "PORT is missing"):
                record.resolve_server_url(Path(temporary))


class OutputDirectoryTest(unittest.TestCase):
    def test_defaults_to_the_html_directory(self) -> None:
        html = Path("C:/animations/demo.html")
        self.assertEqual(record.resolve_output_directory(None, html), html.parent)

    def test_uses_the_requested_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            expected = Path(temporary).resolve()
            self.assertEqual(record.resolve_output_directory(temporary, Path("C:/animations/demo.html")), expected)


class CommandTest(unittest.TestCase):
    def test_record_command_uses_ddagrab_crop_and_nvenc(self) -> None:
        command = record.build_record_command(
            Path("ffmpeg.exe"), MONITOR, CAPTURE, 60, record.GPU_ENCODERS[0], Path("raw.mp4"),
        )
        self.assertIn(
            "ddagrab=output_idx=1:framerate=60:draw_mouse=0:video_size=3840x2160:offset_x=100:offset_y=200",
            command,
        )
        self.assertIn("hwdownload,format=bgra,format=yuv420p", command)
        self.assertIn("hevc_nvenc", command)
        self.assertIn("-progress", command)
        self.assertEqual(command[-1], "raw.mp4")

    def test_record_command_uses_the_fast_preset_and_the_fixed_quality(self) -> None:
        encoder = record.GPU_ENCODERS[0]
        command = record.build_record_command(
            Path("ffmpeg.exe"), MONITOR, CAPTURE, 60, encoder, Path("raw.mp4"),
        )
        self.assertEqual(command[command.index("-preset") + 1], encoder.fast_preset)
        self.assertEqual(command[command.index("-cq") + 1], str(record.QUALITY))

    def test_trim_command_uses_the_final_preset_and_the_same_quality(self) -> None:
        encoder = record.GPU_ENCODERS[0]
        command = record.build_trim_command(
            Path("ffmpeg.exe"), Path("raw.mp4"), Path("out.mp4"), 0.0, 15.0, 60, encoder,
        )
        self.assertEqual(command[command.index("-preset") + 1], encoder.final_preset)
        self.assertEqual(command[command.index("-cq") + 1], str(record.QUALITY))

    def test_cpu_encoder_uses_crf_instead_of_cq(self) -> None:
        command = record.build_record_command(
            Path("ffmpeg.exe"), MONITOR, CAPTURE, 60, record.CPU_ENCODER, Path("raw.mp4"),
        )
        self.assertIn("libx264", command)
        self.assertNotIn("-cq", command)
        self.assertEqual(command[command.index("-crf") + 1], str(record.QUALITY))
        self.assertEqual(command[command.index("-preset") + 1], record.CPU_ENCODER.fast_preset)

    def test_trim_command_cuts_from_the_animation_start(self) -> None:
        encoder = record.GPU_ENCODERS[1]
        command = record.build_trim_command(
            Path("ffmpeg.exe"), Path("raw.mp4"), Path("out.mp4"), 0.8, 15.0, 60, encoder,
        )
        self.assertEqual(command[command.index("-ss") + 1], "0.800")
        self.assertLess(command.index("-ss"), command.index("-i"))
        self.assertEqual(command[command.index("-t") + 1], "15.000")
        self.assertIn("h264_nvenc", command)
        self.assertEqual(command[command.index("-preset") + 1], encoder.final_preset)
        self.assertEqual(command[command.index("-cq") + 1], str(record.QUALITY))
        self.assertEqual(command[-1], "out.mp4")

    def test_cpu_trim_command_uses_crf_and_the_final_preset(self) -> None:
        command = record.build_trim_command(
            Path("ffmpeg.exe"), Path("raw.mp4"), Path("out.mp4"), 0.0, 15.0, 60, record.CPU_ENCODER,
        )
        self.assertEqual(command[command.index("-preset") + 1], "medium")
        self.assertEqual(command[command.index("-crf") + 1], str(record.QUALITY))

    def test_trim_command_clamps_negative_numbers(self) -> None:
        command = record.build_trim_command(
            Path("ffmpeg.exe"), Path("raw.mp4"), Path("out.mp4"), -0.5, -1.2, 60, record.GPU_ENCODERS[0],
        )
        self.assertEqual(command[command.index("-ss") + 1], "0.000")
        self.assertEqual(command[command.index("-t") + 1], "0.000")


class EncoderTest(unittest.TestCase):
    @patch("record.encoder_available", side_effect=lambda _ffmpeg, name: name == "hevc_nvenc")
    def test_prefers_hevc_nvenc(self, _available) -> None:
        self.assertEqual(record.pick_encoder(Path("ffmpeg.exe")).name, "hevc_nvenc")

    @patch("record.encoder_available", side_effect=lambda _ffmpeg, name: name == "h264_nvenc")
    def test_falls_back_to_h264_nvenc(self, _available) -> None:
        self.assertEqual(record.pick_encoder(Path("ffmpeg.exe")).name, "h264_nvenc")

    @patch("record.encoder_available", return_value=False)
    def test_falls_back_to_the_cpu_encoder(self, _available) -> None:
        self.assertEqual(record.pick_encoder(Path("ffmpeg.exe")), record.CPU_ENCODER)


class CaptureWithinTest(unittest.TestCase):
    def test_accepts_a_capture_inside_the_monitor(self) -> None:
        monitor = record.Monitor(index=1, x=3840, y=0, width=3840, height=2160)
        self.assertTrue(record.capture_within(record.Capture(x=3840, y=0, width=3840, height=2160), monitor))
        self.assertTrue(record.capture_within(record.Capture(x=3840, y=100, width=3840, height=2000), monitor))

    def test_rejects_a_capture_from_another_display(self) -> None:
        monitor = record.Monitor(index=1, x=3840, y=0, width=3840, height=2160)
        self.assertFalse(record.capture_within(record.Capture(x=0, y=0, width=3840, height=2160), monitor))


class MonitorTest(unittest.TestCase):
    def test_picks_the_secondary_display(self) -> None:
        monitors = [
            record.Monitor(index=0, x=0, y=0, width=3840, height=2160, primary=True),
            record.Monitor(index=1, x=3840, y=0, width=3840, height=2160),
        ]
        with patch("record.enum_monitors", return_value=monitors):
            self.assertEqual(record.resolve_monitor().index, 1)

    def test_picks_the_secondary_display_on_the_left(self) -> None:
        monitors = [
            record.Monitor(index=0, x=-2560, y=0, width=2560, height=1440),
            record.Monitor(index=1, x=0, y=0, width=3840, height=2160, primary=True),
        ]
        with patch("record.enum_monitors", return_value=monitors):
            self.assertEqual(record.resolve_monitor().index, 0)

    def test_falls_back_to_the_only_display(self) -> None:
        monitors = [record.Monitor(index=0, x=0, y=0, width=3840, height=2160, primary=True)]
        with patch("record.enum_monitors", return_value=monitors):
            self.assertEqual(record.resolve_monitor().index, 0)

    def test_rejects_a_machine_without_displays(self) -> None:
        with patch("record.enum_monitors", return_value=[]):
            with self.assertRaisesRegex(record.RecordError, "No display"):
                record.resolve_monitor()


class ProgressTest(unittest.TestCase):
    def test_reads_frame_counter(self) -> None:
        self.assertEqual(record.parse_progress_frame("frame=42\n"), 42)
        self.assertEqual(record.parse_progress_frame("frame= 42"), 42)
        self.assertIsNone(record.parse_progress_frame("fps=60.00"))
        self.assertIsNone(record.parse_progress_frame("progress=continue"))

    def test_reads_rate(self) -> None:
        self.assertEqual(record.parse_rate("60/1"), 60.0)
        self.assertEqual(record.parse_rate("30000/1001"), 30000 / 1001)
        self.assertEqual(record.parse_rate("garbage"), 0.0)


class OpenTest(unittest.TestCase):
    @patch("record.post_json")
    def test_open_returns_title_and_duration(self, post_json) -> None:
        post_json.return_value = {
            "animation": "demo",
            "title": "一段文字",
            "durationMs": 15000,
            "requestedWallClockMs": 1_700_000_000_123,
            "openedWallClockMs": 1_700_000_000_900,
        }
        opened = record.open_animation("http://127.0.0.1:33714", Path("C:/input/demo.html"))
        self.assertEqual(opened.animation, "demo")
        self.assertEqual(opened.title, "一段文字")
        self.assertEqual(opened.duration_seconds, 15.0)
        post_json.assert_called_once_with(
            "http://127.0.0.1:33714",
            "/animation/open",
            {"htmlPath": str(Path("C:/input/demo.html"))},
        )

    @patch("record.post_json")
    def test_open_sends_the_duration_override(self, post_json) -> None:
        post_json.return_value = {"animation": "demo", "title": "demo", "durationMs": 2000}
        record.open_animation("http://127.0.0.1:1", Path("demo.html"), 2.0)
        self.assertEqual(post_json.call_args[0][2], {"htmlPath": "demo.html", "duration": 2.0})

    @patch("record.post_json")
    def test_open_rejects_missing_animation(self, post_json) -> None:
        post_json.return_value = {"openedWallClockMs": 1}
        with self.assertRaisesRegex(record.RecordError, "animation name"):
            record.open_animation("http://127.0.0.1:1", Path("demo.html"))

    @patch("record.post_json")
    def test_open_rejects_missing_title(self, post_json) -> None:
        post_json.return_value = {"animation": "demo", "durationMs": 15000}
        with self.assertRaisesRegex(record.RecordError, "page title"):
            record.open_animation("http://127.0.0.1:1", Path("demo.html"))

    @patch("record.post_json")
    def test_open_rejects_missing_duration(self, post_json) -> None:
        post_json.return_value = {"animation": "demo", "title": "demo"}
        with self.assertRaisesRegex(record.RecordError, "durationMs"):
            record.open_animation("http://127.0.0.1:1", Path("demo.html"))


class CloseTest(unittest.TestCase):
    @patch("record.post_json")
    def test_close_posts_to_the_close_endpoint(self, post_json) -> None:
        record.close_animation("http://127.0.0.1:33714")
        post_json.assert_called_once_with("http://127.0.0.1:33714", "/animation/close", {})

    @patch("record.post_json")
    def test_close_failure_only_warns(self, post_json) -> None:
        post_json.side_effect = record.RecordError("service is gone")
        record.close_animation("http://127.0.0.1:1")


class PlayTest(unittest.TestCase):
    @patch("record.post_json")
    def test_play_presses_space_without_a_body(self, post_json) -> None:
        post_json.return_value = {"animation": "demo", "requestedWallClockMs": 1_700_000_000_123, "playedWallClockMs": 1_700_000_000_456}
        played = record.play_animation("http://127.0.0.1:33714")
        self.assertEqual(played.animation, "demo")
        self.assertEqual(played.played_wall_clock_ms, 1_700_000_000_456.0)
        post_json.assert_called_once_with("http://127.0.0.1:33714", "/animation/play", {})

    @patch("record.post_json")
    def test_play_rejects_missing_wall_clock(self, post_json) -> None:
        post_json.return_value = {"animation": "demo"}
        with self.assertRaisesRegex(record.RecordError, "playedWallClockMs"):
            record.play_animation("http://127.0.0.1:1")


class DetectTest(unittest.TestCase):
    def test_reads_frame_differences(self) -> None:
        text = (
            "frame:0    pts:0       pts_time:0\n"
            "lavfi.signalstats.YAVG=0\n"
            "frame:1    pts:256     pts_time:0.0166667\n"
            "lavfi.signalstats.YAVG=0.157\n"
        )
        self.assertEqual(record.parse_frame_differences(text), [(0.0, 0.0), (0.0166667, 0.157)])

    def test_finds_the_first_moving_frame(self) -> None:
        differences = [(index * 0.0166667, 0.0) for index in range(20)]
        differences.append((20 * 0.0166667, 0.157))
        differences.append((21 * 0.0166667, 1.4))
        found = record.find_first_movement(differences)
        self.assertAlmostEqual(found, 20 * 0.0166667)

    def test_reads_a_mean_in_scientific_notation(self) -> None:
        # A handful of changed pixels prints as an exponent; reading it as 1.9 would fake movement.
        text = (
            "frame:0    pts:0       pts_time:0\n"
            "lavfi.signalstats.YAVG=1.97531e-05\n"
            "frame:1    pts:256     pts_time:0.0166667\n"
            "lavfi.signalstats.YAVG=0\n"
        )
        differences = record.parse_frame_differences(text)
        self.assertAlmostEqual(differences[0][1], 1.97531e-05)
        self.assertIsNone(record.find_first_movement(differences))

    def test_noise_alone_is_not_movement(self) -> None:
        differences = [(index * 0.0166667, 0.04) for index in range(30)]
        self.assertIsNone(record.find_first_movement(differences))

    def test_small_spots_are_not_movement(self) -> None:
        # A cursor-sized speck on the still page scores far below a caption or hint popping.
        differences = [(index * 0.0166667, 0.03) for index in range(30)]
        self.assertIsNone(record.find_first_movement(differences))

    def test_empty_analysis_has_no_movement(self) -> None:
        self.assertIsNone(record.find_first_movement([]))

    @patch("record.subprocess.run")
    def test_detection_analyses_a_thumbnail(self, run) -> None:
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=(
                "frame:0    pts:0       pts_time:0\n"
                "lavfi.signalstats.YAVG=0\n"
                "frame:1    pts:256     pts_time:0.7\n"
                "lavfi.signalstats.YAVG=0.6\n"
            ),
            stderr="",
        )
        found = record.detect_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.5, 3.0)
        self.assertAlmostEqual(found, 1.2)
        command = run.call_args[0][0]
        self.assertEqual(command[command.index("-ss") + 1], "0.500")
        self.assertEqual(command[command.index("-t") + 1], "3.000")
        self.assertIn(
            "scale=480:-2,format=gray,tblend=all_mode=difference,"
            "geq=lum='if(gt(lum(X,Y),8),255,0)',signalstats,metadata=print:file=-",
            command,
        )


    @patch("record.subprocess.run")
    def test_detection_failure_returns_none(self, run) -> None:
        run.return_value = subprocess.CompletedProcess(args=[], returncode=1, stdout="", stderr="no decoder")
        self.assertIsNone(record.detect_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.0, 3.0))


class AnimationStartTest(unittest.TestCase):
    @patch("record.detect_animation_start")
    def test_uses_the_detected_frame(self, detect) -> None:
        detect.return_value = 0.42
        self.assertAlmostEqual(record.find_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.3), 0.42)

    @patch("record.detect_animation_start")
    def test_a_quiet_opening_cuts_on_the_press(self, detect) -> None:
        # Thin rules darkening and digits ticking stay under the thumbnail threshold, so the first
        # detected frame arrives a second late; the press keeps the whole declared timeline.
        detect.return_value = 1.083
        self.assertAlmostEqual(record.find_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.015), 0.015)

    @patch("record.detect_animation_start")
    def test_a_start_past_the_capture_margin_cuts_on_the_press(self, detect) -> None:
        detect.return_value = record.DETECTION_MAX_LEAD_SECONDS + 0.5
        self.assertAlmostEqual(record.find_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.0), 0.0)

    @patch("record.detect_animation_start")
    def test_no_detection_cuts_on_the_press(self, detect) -> None:
        detect.return_value = None
        self.assertAlmostEqual(record.find_animation_start(Path("ffmpeg.exe"), Path("raw.mp4"), 0.02), 0.02)


class VerifyTest(unittest.TestCase):
    def test_accepts_matching_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "demo.mp4"
            output.write_bytes(b"video")
            with patch("record.probe_video") as probe:
                probe.return_value = record.VideoInfo(width=3840, height=2160, fps=60.0, duration_seconds=15.0)
                video = record.verify_output(Path("ffprobe.exe"), output, CAPTURE, 60, 15.0)
            self.assertEqual(video.width, 3840)

    def test_rejects_resolution_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "demo.mp4"
            output.write_bytes(b"video")
            with patch("record.probe_video") as probe:
                probe.return_value = record.VideoInfo(width=1920, height=1080, fps=60.0, duration_seconds=15.0)
                with self.assertRaisesRegex(record.RecordError, "expected 3840x2160"):
                    record.verify_output(Path("ffprobe.exe"), output, CAPTURE, 60, 15.0)

    def test_rejects_duration_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "demo.mp4"
            output.write_bytes(b"video")
            with patch("record.probe_video") as probe:
                probe.return_value = record.VideoInfo(width=3840, height=2160, fps=60.0, duration_seconds=14.5)
                with self.assertRaisesRegex(record.RecordError, "expected 15.000"):
                    record.verify_output(Path("ffprobe.exe"), output, CAPTURE, 60, 15.0)

    def test_rejects_missing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(record.RecordError, "missing or empty"):
                record.verify_output(Path("ffprobe.exe"), Path(temporary) / "demo.mp4", CAPTURE, 60, 15.0)


if __name__ == "__main__":
    unittest.main()
