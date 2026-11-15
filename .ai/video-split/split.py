#!/usr/bin/env python3
"""
Split a single video file into two precisely timed H.264/AAC MP4 files using FFmpeg.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/video-split/split.py --video path/to/video.mp4
    .dependency/python/python .ai/video-split/split.py --video path/to/video.mp4 -s 12.5
    .dependency/python/python .ai/video-split/split.py --video path/to/video.mp4 -p 30
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_dir_help, resolve_output_dir  # noqa: E402
from common.video_utils import resolve_video_file  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "video-split"


def get_duration(ffprobe: Path, file_path: Path) -> float:
    result = subprocess.run(
        [str(ffprobe), "-v", "error", "-show_entries", "format=duration", "-of", "json", str(file_path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"Could not probe duration: {file_path}")
    try:
        duration = float(json.loads(result.stdout)["format"]["duration"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Could not determine video duration: {file_path}") from exc
    if duration <= 0:
        raise RuntimeError(f"Video duration must be positive: {file_path}")
    return duration


def resolve_split_seconds(duration: float, split_at: float | None, percent: float | None) -> float:
    point = split_at if split_at is not None else duration * ((percent if percent is not None else 50.0) / 100.0)
    if point <= 0:
        raise ValueError("Split point must be after the start (> 0 seconds).")
    if point >= duration:
        raise ValueError(f"Split point ({point:.3f}s) must be before video end ({duration:.3f}s).")
    return point


def output_paths(out_dir: Path, file_path: Path) -> tuple[Path, Path]:
    return out_dir / f"{file_path.stem}_part1.mp4", out_dir / f"{file_path.stem}_part2.mp4"


def encode_part(ffmpeg: Path, file_path: Path, output: Path, start: float | None, duration: float) -> None:
    cmd = [str(ffmpeg), "-hide_banner", "-nostats", "-y"]
    if start is not None:
        cmd.extend(["-ss", f"{start:.6f}"])
    cmd.extend(["-i", str(file_path), "-t", f"{duration:.6f}", "-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(output)])
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"FFmpeg failed writing: {output}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Split one video into two precisely timed MP4 parts.")
    parser.add_argument("--video", required=True, help="Path to a single video file")
    split = parser.add_mutually_exclusive_group()
    split.add_argument("-s", "--split-at", type=float, help="Split time in seconds")
    split.add_argument("-p", "--percent", type=float, help="Split position as a percentage (default: 50)")
    default_out = format_default_output_dir_help(DEFAULT_OUTPUT_SUBDIR, input_root_label="video-dir")
    parser.add_argument("-o", "--output", default="", help=f"Output directory (default: {default_out})")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    configure_utf8_stdio()
    args = parse_args(argv)
    ffmpeg = resolve_ffmpeg(Path(__file__))
    ffprobe = resolve_ffprobe(ffmpeg)
    video_path = resolve_video_file(args.video)
    if video_path is None:
        return 1
    out_dir = resolve_output_dir(args.output, video_path.parent, output_subdir=DEFAULT_OUTPUT_SUBDIR)
    part1, part2 = output_paths(out_dir, video_path)
    try:
        duration = get_duration(ffprobe, video_path)
        split_at = resolve_split_seconds(duration, args.split_at, args.percent)
    except (RuntimeError, ValueError) as exc:
        print(f"[fail] {video_path.name}\n{exc}", file=sys.stderr)
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Video:  {video_path}\nSplit:  {split_at:.3f}s / {duration:.3f}s\nOutput: {part1}\n        {part2}\n")
    try:
        encode_part(ffmpeg, video_path, part1, None, split_at)
        encode_part(ffmpeg, video_path, part2, split_at, duration - split_at)
    except RuntimeError as exc:
        print(f"[fail] {video_path.name}\n{exc}", file=sys.stderr)
        return 1
    print(f"Done. wrote {part1.name} and {part2.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
