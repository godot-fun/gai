#!/usr/bin/env python3
"""Convert one video file to a broadly compatible H.264/AAC MP4."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402
from common.video_utils import resolve_video_file, video_output_name  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "video-to-mp4"
DEFAULT_CRF = 18
DEFAULT_PRESET = "slow"
DEFAULT_AUDIO_BITRATE = "192k"
PRESETS = ("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")


def probe_streams(ffprobe: Path, file_path: Path) -> dict:
    result = subprocess.run(
        [str(ffprobe), "-v", "quiet", "-print_format", "json", "-show_streams", str(file_path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 0:
        return {"video": {}, "audio": {}}
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"video": {}, "audio": {}}
    video: dict = {}
    audio: dict = {}
    for stream in payload.get("streams") or []:
        if stream.get("codec_type") == "video" and not video:
            video = {"codec": stream.get("codec_name", ""), "pix_fmt": stream.get("pix_fmt", ""), "width": stream.get("width"), "height": stream.get("height"), "frame_rate": stream.get("avg_frame_rate", "")}
        elif stream.get("codec_type") == "audio" and not audio:
            audio = {"codec": stream.get("codec_name", ""), "sample_rate": stream.get("sample_rate"), "channels": stream.get("channels")}
    return {"video": video, "audio": audio}


def can_stream_copy(file_path: Path, probe: dict, force_encode: bool = False) -> bool:
    if force_encode or file_path.suffix.lower() != ".mp4":
        return False
    video = probe.get("video") or {}
    audio = probe.get("audio") or {}
    return video.get("codec") == "h264" and video.get("pix_fmt") in {"yuv420p", "yuvj420p"} and (not audio or audio.get("codec") == "aac")


def build_ffmpeg_args(ffmpeg: Path, file_path: Path, out_path: Path, probe: dict, crf: int, preset: str, audio_bitrate: str, stream_copy: bool) -> list[str]:
    cmd = [str(ffmpeg), "-hide_banner", "-nostats", "-y", "-i", str(file_path), "-map", "0:v:0", "-map", "0:a:0?"]
    if stream_copy:
        cmd.extend(["-c", "copy", "-movflags", "+faststart", str(out_path)])
        return cmd
    cmd.extend(["-c:v", "libx264", "-preset", preset, "-crf", str(crf), "-profile:v", "high", "-pix_fmt", "yuv420p"])
    if probe.get("audio"):
        cmd.extend(["-c:a", "aac", "-b:a", audio_bitrate])
    else:
        cmd.append("-an")
    cmd.extend(["-movflags", "+faststart", str(out_path)])
    return cmd


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert a single video file to H.264/AAC MP4.")
    parser.add_argument("--video", required=True, help="Path to a single video file")
    parser.add_argument("-o", "--output", default="", help=f"Output MP4 file or directory. Default: {format_default_output_help(DEFAULT_OUTPUT_SUBDIR, output_name_label='source.mp4')}")
    parser.add_argument("--crf", type=int, choices=range(0, 52), default=DEFAULT_CRF, metavar="0-51", help=f"H.264 constant quality (default: {DEFAULT_CRF}; lower is higher quality)")
    parser.add_argument("--preset", choices=PRESETS, default=DEFAULT_PRESET, help=f"x264 encoding preset (default: {DEFAULT_PRESET})")
    parser.add_argument("--audio-bitrate", default=DEFAULT_AUDIO_BITRATE, help=f"AAC bitrate (default: {DEFAULT_AUDIO_BITRATE})")
    parser.add_argument("--force-encode", action="store_true", help="Re-encode even when the source is already a compatible MP4")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    configure_utf8_stdio()
    args = parse_args(argv)
    script_path = Path(__file__)
    ffmpeg = resolve_ffmpeg(script_path)
    ffprobe = resolve_ffprobe(ffmpeg)
    video_path = resolve_video_file(args.video)
    if video_path is None:
        return 1
    out_path = resolve_output_path(args.output, video_path, DEFAULT_OUTPUT_SUBDIR, video_output_name(video_path, suffix=".mp4"))
    if out_path.resolve() == video_path.resolve():
        print(f"Refusing to overwrite source file. Choose a separate output path (default: {DEFAULT_OUTPUT_SUBDIR}/).", file=sys.stderr)
        return 1
    probe = probe_streams(ffprobe, video_path)
    if not probe.get("video"):
        print(f"[fail] {video_path.name} (no video stream)", file=sys.stderr)
        return 1
    stream_copy = can_stream_copy(video_path, probe, args.force_encode)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    mode = "stream copy" if stream_copy else f"H.264 CRF {args.crf} ({args.preset}) + AAC {args.audio_bitrate}"
    print(f"Video:  {video_path}\nMode:   {mode}\nOutput: {out_path}\n")
    cmd = build_ffmpeg_args(ffmpeg, video_path, out_path, probe, args.crf, args.preset, args.audio_bitrate, stream_copy)
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        print(f"[fail] {out_path.name}\n{detail}", file=sys.stderr)
        return 1
    print(f"Done. wrote {out_path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
