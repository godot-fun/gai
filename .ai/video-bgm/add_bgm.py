#!/usr/bin/env python3
"""
Add one or more background audio tracks to a single video using FFmpeg.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/video-bgm/add_bgm.py --video path/to/clip.mp4 --audio path/to/music-folder
    .dependency/python/python .ai/video-bgm/add_bgm.py --video path/to/clip.mp4 --audio path/to/music-folder -o path/to/out.mp4
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.audio_utils import AUDIO_EXTENSIONS, get_duration  # noqa: E402
from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402
from common.video_utils import resolve_video_file, video_output_name  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "video-bgm"
BGM_VOLUME = 0.20
MAX_CROSSFADE_SECONDS = 1.0
MAX_FADE_OUT_SECONDS = 2.0


def has_audio_stream(ffprobe: Path, file_path: Path) -> bool:
    result = subprocess.run(
        [str(ffprobe), "-v", "quiet", "-print_format", "json", "-show_streams", "-select_streams", "a", str(file_path)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        raise RuntimeError(f"Could not inspect audio streams for: {file_path}")
    try:
        return bool(json.loads(result.stdout).get("streams"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid ffprobe output for: {file_path}") from exc


def crossfade_duration(durations: list[float]) -> float:
    if len(durations) < 2:
        return 0.0
    return min(MAX_CROSSFADE_SECONDS, min(durations) / 2.0)


def natural_sort_key(path: Path) -> list[tuple[int, int | str]]:
    parts = re.split(r"(\d+)", path.name.casefold())
    return [(0, int(part)) if part.isdigit() else (1, part) for part in parts]


def resolve_audio_input(raw_path: str) -> list[Path] | None:
    path = Path(raw_path).expanduser()
    if not path.exists():
        print(f"Audio folder not found: {raw_path}", file=sys.stderr)
        return None
    if not path.is_dir():
        print(f"Not an audio folder (files are not supported): {raw_path}", file=sys.stderr)
        return None
    audio_paths = [candidate.resolve() for candidate in path.iterdir()
                   if candidate.is_file() and candidate.suffix.lower() in AUDIO_EXTENSIONS]
    audio_paths.sort(key=natural_sort_key)
    if not audio_paths:
        print(f"No supported audio files found in folder: {path.resolve()}", file=sys.stderr)
        return None
    return audio_paths


def build_bed_args(ffmpeg: Path, audio_paths: list[Path], durations: list[float], bed_path: Path) -> list[str]:
    cmd = [str(ffmpeg), "-hide_banner", "-nostats", "-y"]
    for audio_path in audio_paths:
        cmd.extend(["-i", str(audio_path)])

    normalized = [f"[{index}:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a{index}]" for index in range(len(audio_paths))]
    fade = crossfade_duration(durations)
    if len(audio_paths) == 1:
        output_label = "a0"
    else:
        previous = "a0"
        for index in range(1, len(audio_paths)):
            output_label = f"bed{index}"
            normalized.append(f"[{previous}][a{index}]acrossfade=d={fade:.6f}:c1=tri:c2=tri[{output_label}]")
            previous = output_label

    cmd.extend(["-filter_complex", ";".join(normalized), "-map", f"[{output_label}]", "-c:a", "pcm_s16le", str(bed_path)])
    return cmd


def audio_codec_args(output_path: Path) -> list[str]:
    suffix = output_path.suffix.lower()
    if suffix in {".webm", ".ogv"}:
        return ["-c:a", "libvorbis", "-q:a", "6"]
    if suffix == ".avi":
        return ["-c:a", "libmp3lame", "-q:a", "2"]
    return ["-c:a", "aac", "-b:a", "192k"]


def build_mix_args(ffmpeg: Path, video_path: Path, bed_path: Path, out_path: Path, duration: float, original_audio: bool) -> list[str]:
    fade_duration = min(MAX_FADE_OUT_SECONDS, duration)
    fade_start = max(0.0, duration - fade_duration)
    bgm_filter = f"[1:a]atrim=0:{duration:.6f},asetpts=PTS-STARTPTS,volume={BGM_VOLUME:.2f},afade=t=out:st={fade_start:.6f}:d={fade_duration:.6f}[bgm]"
    if original_audio:
        filter_complex = bgm_filter + f";[0:a:0]atrim=0:{duration:.6f},asetpts=PTS-STARTPTS[original];[original][bgm]amix=inputs=2:duration=longest:dropout_transition=0[aout]"
    else:
        filter_complex = bgm_filter.replace("[bgm]", "[aout]")

    cmd = [str(ffmpeg), "-hide_banner", "-nostats", "-y", "-i", str(video_path), "-stream_loop", "-1", "-i", str(bed_path), "-filter_complex", filter_complex, "-map", "0:v:0", "-map", "[aout]", "-c:v", "copy"]
    cmd.extend(audio_codec_args(out_path))
    cmd.extend(["-t", f"{duration:.6f}", str(out_path)])
    return cmd


def run_ffmpeg(cmd: list[str], action: str) -> None:
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"FFmpeg {action} failed" + (f"\n{detail}" if detail else ""))


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Add background audio to a single video.")
    parser.add_argument("--video", required=True, help="Path to a single video file")
    parser.add_argument("--audio", required=True, help="Path to one folder of audio files")
    parser.add_argument("-o", "--output", default="", help="Output video file or directory. " + f"Default: {format_default_output_help(DEFAULT_OUTPUT_SUBDIR)}")
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
    audio_paths = resolve_audio_input(args.audio)
    if audio_paths is None:
        return 1

    out_path = resolve_output_path(args.output, video_path, DEFAULT_OUTPUT_SUBDIR, video_output_name(video_path))
    source_paths = {video_path.resolve(), *(path.resolve() for path in audio_paths)}
    if out_path.resolve() in source_paths:
        print("Refusing to overwrite a source file. Choose a separate output path.", file=sys.stderr)
        return 1

    try:
        video_duration = get_duration(ffprobe, video_path)
        durations = [get_duration(ffprobe, path) for path in audio_paths]
        if video_duration <= 0 or any(duration <= 0 for duration in durations):
            raise RuntimeError("Video and audio durations must be greater than zero")
        original_audio = has_audio_stream(ffprobe, video_path)

        out_path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="video-bgm-") as temp_dir:
            bed_path = Path(temp_dir) / "music-bed.wav"
            print(f"Video:  {video_path}")
            print(f"Audio:  {len(audio_paths)} file(s)")
            print(f"Mode:   {'mix with original audio' if original_audio else 'add to silent video'}")
            print(f"Output: {out_path}")
            print()
            print("[1/2] Building music bed")
            run_ffmpeg(build_bed_args(ffmpeg, audio_paths, durations, bed_path), "music-bed")
            print("[2/2] Mixing BGM into video")
            run_ffmpeg(build_mix_args(ffmpeg, video_path, bed_path, out_path, video_duration, original_audio), "BGM mix")
    except RuntimeError as exc:
        print(f"[fail] {out_path.name}", file=sys.stderr)
        print(exc, file=sys.stderr)
        return 1

    print()
    print(f"Done. wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
