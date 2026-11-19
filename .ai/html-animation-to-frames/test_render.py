#!/usr/bin/env python3
"""Unit tests for render.py; no browser or live web service is used."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import render  # noqa: E402


class RenderTest(unittest.TestCase):
    def test_server_url_prefers_env(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            web = Path(temporary)
            (web / ".env").write_text("HOST = 127.0.0.2\nPORT = 4000\n", encoding="utf-8")
            (web / ".env.example").write_text("HOST = 127.0.0.3\nPORT = 5000\n", encoding="utf-8")
            self.assertEqual(render.resolve_server_url(web), "http://127.0.0.2:4000")

    def test_server_url_falls_back_to_example_per_field(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            web = Path(temporary)
            (web / ".env").write_text("HOST = 127.0.0.2\n", encoding="utf-8")
            (web / ".env.example").write_text("HOST = 127.0.0.3\nPORT = 5000\n", encoding="utf-8")
            self.assertEqual(render.resolve_server_url(web), "http://127.0.0.2:5000")

    def test_server_url_requires_port_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(RuntimeError, "PORT is missing"):
                render.resolve_server_url(Path(temporary))

    @patch("render.post_json")
    def test_create_animation(self, post_json) -> None:
        post_json.return_value = {"animation": "demo"}
        animation = render.create_animation("C:/input/demo.html", "C:/output")
        self.assertEqual(animation, "demo")
        post_json.assert_called_once_with(
            "/animation/create",
            {"htmlPath": "C:/input/demo.html", "outputDirectory": "C:/output"},
        )

    @patch("render.time.sleep")
    @patch("render.post_json")
    def test_wait_until_completed(self, post_json, sleep) -> None:
        post_json.side_effect = [
            {"status": "rendering", "error": ""},
            {"status": "completed", "error": ""},
        ]
        render.wait_for_animation("demo", "C:/output")
        sleep.assert_called_once_with(render.POLL_INTERVAL_SECONDS)

    @patch("render.post_json")
    def test_failed_render_raises_service_error(self, post_json) -> None:
        post_json.return_value = {"status": "failed", "error": "page error"}
        with self.assertRaisesRegex(render.RenderError, "page error"):
            render.wait_for_animation("demo", "C:/output")

    def test_verify_completed_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            directory = output / "demo"
            directory.mkdir()
            manifest = {
                "status": "completed",
                "width": 1920,
                "height": 1080,
                "fps": 60,
                "totalFrames": 2,
                "renderedFrames": 2,
            }
            (directory / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            (directory / "000000.png").write_bytes(b"first")
            (directory / "000001.png").write_bytes(b"last")
            self.assertEqual(render.verify_output("demo", str(output)), manifest)

    def test_verify_rejects_missing_frames(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            directory = output / "demo"
            directory.mkdir()
            manifest = {"status": "completed", "totalFrames": 2, "renderedFrames": 2}
            (directory / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            (directory / "000000.png").write_bytes(b"first")
            with self.assertRaisesRegex(render.RenderError, "PNG frame count is incomplete"):
                render.verify_output("demo", str(output))


if __name__ == "__main__":
    raise SystemExit(unittest.main())
