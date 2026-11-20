#!/usr/bin/env python3
"""Tests for parse_storyboard.py."""

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

import parse_storyboard  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
PARSE_SCRIPT = SCRIPT_DIR / "parse_storyboard.py"

SAMPLE_STORYBOARD = """\
# Storyboard — Demo Title

### Shot 01 — Hook
- **Chinese:** Greetings to the world.
- **English:** Hello world.
- **Duration:** 3s

### Shot 02 — Body
- **Chinese:** (no VO)
- **English:** Second line here! And a third.
- **Duration:** 5s
"""

SAMPLE_NARRATION = """\
# Narration Script — Product Demo

## Chinese

### 01 — 开场
世界，你好。

### 02
(no VO)

## English

### 01 — Opening
Hello, world.

### 02
This is the second line.
"""


class ParseLogicTest(unittest.TestCase):
    def test_parses_language_sections(self) -> None:
        data = parse_storyboard.parse_storyboard(SAMPLE_NARRATION)
        self.assertEqual(data["title"], "Product Demo")
        self.assertEqual(data["shot_count"], 2)
        self.assertEqual(data["shots"][0]["title"], "开场")
        self.assertEqual(data["shots"][0]["chinese"], "世界，你好。")
        self.assertEqual(data["shots"][0]["english"], "Hello, world.")
        self.assertTrue(data["shots"][1]["chinese_skip"])
        self.assertEqual(data["shots"][1]["english"], "This is the second line.")

    def test_parses_text_fields_in_language_sections(self) -> None:
        markdown = """# Narration Script — Fields
## Chinese
### 01
- **Text:** 中文台词
## English
### 01
- **Text:** English line
"""
        data = parse_storyboard.parse_storyboard(markdown)
        self.assertEqual(data["shots"][0]["chinese"], "中文台词")
        self.assertEqual(data["shots"][0]["english"], "English line")

    def test_parses_title_and_shots(self) -> None:
        data = parse_storyboard.parse_storyboard(SAMPLE_STORYBOARD)
        self.assertEqual(data["title"], "Demo Title")
        self.assertEqual(data["shot_count"], 2)
        self.assertEqual(data["shots"][0]["id"], "01")
        self.assertEqual(data["shots"][0]["chinese"], "Greetings to the world.")
        self.assertFalse(data["shots"][0]["chinese_skip"])
        self.assertEqual(data["shots"][1]["english"], "Second line here! And a third.")
        self.assertTrue(data["shots"][1]["chinese_skip"])

    def test_is_no_vo(self) -> None:
        self.assertTrue(parse_storyboard.is_no_vo("(no VO)"))
        self.assertTrue(parse_storyboard.is_no_vo(""))
        self.assertFalse(parse_storyboard.is_no_vo("Hello"))


class ParseCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(PYTHON_BIN), str(PARSE_SCRIPT), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=str(REPO_ROOT),
        )

    def test_help(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("storyboard", result.stdout.lower())

    def test_writes_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            md = Path(tmp) / "board.md"
            out = Path(tmp) / "shots.json"
            md.write_text(SAMPLE_STORYBOARD, encoding="utf-8")
            result = self.run_cli(str(md), "-o", str(out))
            self.assertEqual(result.returncode, 0)
            self.assertTrue(out.is_file())
            self.assertIn('"shot_count": 2', out.read_text(encoding="utf-8"))

    def test_missing_file(self) -> None:
        result = self.run_cli("missing-storyboard.md")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not found", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
