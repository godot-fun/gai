#!/usr/bin/env python3
"""
Parse narration markdown into paired Chinese / English VO lines.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/storyboard-tts/parse_storyboard.py path/to/storyboard.md
    .dependency/python/python .ai/storyboard-tts/parse_storyboard.py storyboard.md -o shots.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.output_utils import configure_utf8_stdio  # noqa: E402

SHOT_HEADER_RE = re.compile(
    r"^###\s+Shot\s+(\d+)\s*[—–\-]\s*(.+?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
LANGUAGE_SECTION_RE = re.compile(
    r"^##\s+(Chinese|English)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
LINE_HEADER_RE = re.compile(
    r"^###\s+(?:Shot\s+)?(\d+)(?:[ \t]*[—–\-:][ \t]*(.*?))?[ \t]*$",
    re.IGNORECASE | re.MULTILINE,
)
FIELD_RE = re.compile(
    r"^\s*[-*]\s+\*\*(?P<key>[^*]+)\*\*\s*:?\s*(?P<value>.*)\s*$",
    re.MULTILINE,
)
TITLE_RE = re.compile(
    r"^#\s+(?:Storyboard|Narration\s+Script)\s*(?:[—–\-]|:)\s*(.+?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
NO_VO_MARKERS = {
    "(no vo)",
    "(no vo.)",
    "no vo",
    "(no narration)",
    "(none)",
    "-",
    "—",
    "n/a",
    "none",
}


def is_no_vo(text: str) -> bool:
    t = text.strip().lower()
    if not t:
        return True
    return t in NO_VO_MARKERS


def normalize_field_key(key: str) -> str:
    return key.strip().lower().replace(" ", "").rstrip(":")


def extract_fields(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for match in FIELD_RE.finditer(block):
        key = normalize_field_key(match.group("key"))
        fields[key] = match.group("value").strip()
    return fields


def extract_line_text(block: str) -> str:
    fields = extract_fields(block)
    if "text" in fields:
        return fields["text"].strip()
    lines = [line.strip() for line in block.strip().splitlines()]
    return "\n".join(line for line in lines if line).strip()


def parse_language_sections(markdown: str) -> dict | None:
    sections = list(LANGUAGE_SECTION_RE.finditer(markdown))
    if not sections:
        return None

    entries: dict[str, dict[str, dict[str, str]]] = {"chinese": {}, "english": {}}
    order: list[str] = []
    for index, section in enumerate(sections):
        language = section.group(1).lower()
        start = section.end()
        end = sections[index + 1].start() if index + 1 < len(sections) else len(markdown)
        body = markdown[start:end]
        headers = list(LINE_HEADER_RE.finditer(body))
        for line_index, header in enumerate(headers):
            raw_id = header.group(1)
            line_id = f"{int(raw_id):02d}"
            title = (header.group(2) or "").strip()
            text_start = header.end()
            text_end = headers[line_index + 1].start() if line_index + 1 < len(headers) else len(body)
            text = extract_line_text(body[text_start:text_end])
            entries[language][line_id] = {"title": title, "text": text}
            if line_id not in order:
                order.append(line_id)

    shots: list[dict] = []
    for line_id in order:
        chinese_entry = entries["chinese"].get(line_id, {})
        english_entry = entries["english"].get(line_id, {})
        chinese = chinese_entry.get("text", "")
        english = english_entry.get("text", "")
        shots.append(
            {
                "id": line_id,
                "title": chinese_entry.get("title") or english_entry.get("title") or "",
                "duration_hint": "",
                "chinese": chinese,
                "english": english,
                "chinese_skip": is_no_vo(chinese),
                "english_skip": is_no_vo(english),
            }
        )

    return {"shot_count": len(shots), "shots": shots}


def parse_storyboard(markdown: str) -> dict:
    title_match = TITLE_RE.search(markdown)
    title = title_match.group(1).strip() if title_match else "Untitled"

    section_data = parse_language_sections(markdown)
    if section_data is not None:
        return {
            "title": title,
            "shot_count": section_data["shot_count"],
            "shots": section_data["shots"],
        }

    headers = list(SHOT_HEADER_RE.finditer(markdown))
    shots: list[dict] = []

    for i, header in enumerate(headers):
        raw_id = header.group(1)
        shot_id = f"{int(raw_id):02d}" if raw_id.isdigit() else raw_id
        shot_title = header.group(2).strip()

        start = header.end()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(markdown)
        next_section = re.search(r"^##\s+\S", markdown[start:end], re.MULTILINE)
        if next_section:
            end = start + next_section.start()

        fields = extract_fields(markdown[start:end])
        chinese = fields.get("chinese", "").strip()
        english = fields.get("english", "").strip()
        duration = fields.get("duration", "").strip()

        shots.append(
            {
                "id": shot_id,
                "title": shot_title,
                "duration_hint": duration,
                "chinese": chinese,
                "english": english,
                "chinese_skip": is_no_vo(chinese),
                "english_skip": is_no_vo(english),
            }
        )

    return {
        "title": title,
        "shot_count": len(shots),
        "shots": shots,
    }


def main(argv: list[str] | None = None) -> int:
    configure_utf8_stdio()
    parser = argparse.ArgumentParser(
        description="Parse storyboard markdown into shot VO JSON.",
    )
    parser.add_argument("storyboard", help="Path to storyboard markdown")
    parser.add_argument(
        "-o",
        "--output",
        help="Write JSON to this path (default: stdout)",
    )
    args = parser.parse_args(argv)

    path = Path(args.storyboard).expanduser()
    if not path.is_file():
        print(f"Storyboard not found: {path}", file=sys.stderr)
        return 1

    data = parse_storyboard(path.read_text(encoding="utf-8-sig"))
    if data["shot_count"] == 0:
        print(
            f"No lines found in {path}. Expected ## Chinese / ## English sections with ### 01 headings",
            file=sys.stderr,
        )
        return 1

    text = json.dumps(data, ensure_ascii=False, indent=2)
    if args.output:
        out = Path(args.output).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text + "\n", encoding="utf-8")
        print(f"Wrote {out} ({data['shot_count']} shots)")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
