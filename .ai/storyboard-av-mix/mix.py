#!/usr/bin/env python3
"""
Mux storyboard shot video with bilingual VO; retime video only (audio master).

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/storyboard-av-mix/mix.py --audio path/to/Audio --video path/to/Video

--audio   VO root holding Chinese/ + English/        (required)
--video   Video root holding Chinese/ + English/     (required)
--output  Output root; defaults to <audio>/Video/    (optional)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.audio_utils import AUDIO_EXTENSIONS  # noqa: E402
from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.output_utils import configure_utf8_stdio  # noqa: E402
from common.video_utils import VIDEO_EXTENSIONS  # noqa: E402

LANG_DIRS = {"chinese": "Chinese", "english": "English"}

# x264/x265 preset: slower encode, better rate-distortion at matched source bitrate.
VIDEO_ENCODE_PRESET = "slow"


class MixError(RuntimeError):
    """Fatal setup problem: missing folders, no clips, bad flag."""


@dataclass(frozen=True)
class MixJob:
    shot_id: str
    lang: str
    video: Path
    audio: Path
    output: Path


@dataclass(frozen=True)
class VideoProbe:
    codec_name: str
    profile: str
    pix_fmt: str
    color_range: str
    color_space: str
    color_transfer: str
    color_primaries: str
    bit_rate: int | None
    mastering: dict = field(default_factory=dict)
    cll: dict = field(default_factory=dict)


def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def probe_json(ffprobe: Path, path: Path, entries: str) -> dict:
    cmd = [
        str(ffprobe),
        "-v",
        "error",
        "-show_entries",
        entries,
        "-of",
        "json",
        str(path),
    ]
    result = run_cmd(cmd)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffprobe failed for {path}:\n{result.stderr.strip() or result.stdout.strip()}"
        )
    return json.loads(result.stdout or "{}")


def probe_duration_seconds(ffprobe: Path, path: Path) -> float:
    """Return media duration in seconds (never modifies file)."""
    data = probe_json(ffprobe, path, "format=duration")
    raw = (data.get("format") or {}).get("duration")
    if raw is None:
        raise RuntimeError(f"No duration in ffprobe output for {path}")
    duration = float(raw)
    if duration <= 0:
        raise RuntimeError(f"Non-positive duration ({duration}) for {path}")
    return duration


def probe_audio_codec(ffprobe: Path, path: Path) -> str:
    cmd = [
        str(ffprobe),
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name",
        "-of",
        "json",
        str(path),
    ]
    result = run_cmd(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"ffprobe audio codec failed for {path}")
    data = json.loads(result.stdout or "{}")
    streams = data.get("streams") or []
    if not streams or not streams[0].get("codec_name"):
        raise RuntimeError(f"No audio stream in {path}")
    return str(streams[0]["codec_name"]).lower()


def _side_num(value: object) -> int:
    """Parse ffprobe fraction/int side-data fields to int numerator."""
    text = str(value)
    if "/" in text:
        return int(text.split("/", 1)[0])
    return int(float(text))


def probe_video(ffprobe: Path, path: Path) -> VideoProbe:
    cmd = [
        str(ffprobe),
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_streams",
        "-of",
        "json",
        str(path),
    ]
    result = run_cmd(cmd)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffprobe video failed for {path}:\n"
            f"{result.stderr.strip() or result.stdout.strip()}"
        )
    data = json.loads(result.stdout or "{}")
    streams = data.get("streams") or []
    if not streams:
        raise RuntimeError(f"No video stream in {path}")
    stream = streams[0]

    mastering: dict = {}
    cll: dict = {}
    for side in stream.get("side_data_list") or []:
        kind = side.get("side_data_type") or ""
        if kind == "Mastering display metadata":
            mastering = side
        elif kind == "Content light level metadata":
            cll = side

    bit_rate_raw = stream.get("bit_rate")
    bit_rate = int(bit_rate_raw) if bit_rate_raw not in (None, "N/A") else None

    return VideoProbe(
        codec_name=str(stream.get("codec_name") or "").lower(),
        profile=str(stream.get("profile") or ""),
        pix_fmt=str(stream.get("pix_fmt") or "yuv420p"),
        color_range=str(stream.get("color_range") or ""),
        color_space=str(stream.get("color_space") or ""),
        color_transfer=str(stream.get("color_transfer") or ""),
        color_primaries=str(stream.get("color_primaries") or ""),
        bit_rate=bit_rate,
        mastering=mastering,
        cll=cll,
    )


def _master_display_x265(mastering: dict) -> str:
    rx = _side_num(mastering["red_x"])
    ry = _side_num(mastering["red_y"])
    gx = _side_num(mastering["green_x"])
    gy = _side_num(mastering["green_y"])
    bx = _side_num(mastering["blue_x"])
    by = _side_num(mastering["blue_y"])
    wx = _side_num(mastering["white_point_x"])
    wy = _side_num(mastering["white_point_y"])
    max_l = _side_num(mastering["max_luminance"])
    min_l = _side_num(mastering["min_luminance"])
    return f"G({gx},{gy})B({bx},{by})R({rx},{ry})WP({wx},{wy})L({max_l},{min_l})"


def video_encode_args(probe: VideoProbe) -> list[str]:
    """Match source codec / bit depth / HDR tags; setpts forces a re-encode."""
    args: list[str] = []
    is_10bit = "10" in probe.pix_fmt or "10" in probe.profile
    hevc_like = probe.codec_name in {"hevc", "h265"}

    if hevc_like or is_10bit:
        args.extend(["-c:v", "libx265", "-tag:v", "hvc1"])
        if is_10bit:
            args.extend(["-profile:v", "main10"])
        args.extend(["-preset", VIDEO_ENCODE_PRESET])
        x265: list[str] = []
        if probe.mastering:
            x265.append(f"master-display={_master_display_x265(probe.mastering)}")
        if probe.cll:
            max_c = int(probe.cll.get("max_content") or 0)
            max_a = int(probe.cll.get("max_average") or 0)
            x265.append(f"max-cll={max_c},{max_a}")
        if x265:
            args.extend(["-x265-params", ":".join(x265)])
    else:
        args.extend(["-c:v", "libx264", "-preset", VIDEO_ENCODE_PRESET])

    args.extend(["-pix_fmt", probe.pix_fmt])

    if probe.color_range:
        args.extend(["-color_range", probe.color_range])
    if probe.color_space:
        args.extend(["-colorspace", probe.color_space])
    if probe.color_primaries:
        args.extend(["-color_primaries", probe.color_primaries])
    if probe.color_transfer:
        args.extend(["-color_trc", probe.color_transfer])

    if probe.bit_rate and probe.bit_rate > 0:
        rate = str(probe.bit_rate)
        args.extend(["-b:v", rate, "-maxrate", rate, "-bufsize", str(probe.bit_rate * 2)])
    else:
        args.extend(["-crf", "14"])

    return args


def audio_encode_args(ffprobe: Path, audio: Path, video_ext: str) -> list[str]:
    """Prefer stream copy; never change VO duration. AAC only when container needs it."""
    codec = probe_audio_codec(ffprobe, audio)
    ext = video_ext.lower()
    pcm_like = codec.startswith("pcm_") or codec in {"wav", "flac", "alaw", "mulaw"}
    mp4_family = ext in {".mp4", ".m4v", ".mov", ".3gp"}
    webm = ext == ".webm"

    if mp4_family and (pcm_like or codec in {"opus", "vorbis", "flac"}):
        return ["-c:a", "aac", "-b:a", "320k"]
    if webm and pcm_like:
        return ["-c:a", "libopus", "-b:a", "192k"]
    return ["-c:a", "copy"]


def list_by_stem(folder: Path, extensions: set[str]) -> dict[str, Path]:
    if not folder.is_dir():
        return {}
    found: dict[str, Path] = {}
    for item in sorted(folder.iterdir()):
        if not item.is_file():
            continue
        ext = item.suffix.lower()
        if ext not in extensions:
            continue
        stem = item.stem
        if stem in found:
            print(
                f"[warn] duplicate stem '{stem}' in {folder.name}/; "
                f"keeping {found[stem].name}, ignoring {item.name}",
                file=sys.stderr,
            )
            continue
        found[stem] = item.resolve()
    return found


def require_dir(value: Path, label: str) -> Path:
    """Resolve a required flag path and fail loudly when it is not a directory."""
    resolved = value.expanduser().resolve()
    if not resolved.is_dir():
        raise MixError(f"{label} not found: {resolved}")
    return resolved


def build_jobs(root: Path, lang: str, video_root: Path, output_root: Path | None = None) -> list[MixJob]:
    langs = ["chinese", "english"] if lang == "both" else [lang]
    output_root = (output_root or root / "Video").expanduser().resolve()
    audio_maps = {
        lang_key: list_by_stem(root / LANG_DIRS[lang_key], AUDIO_EXTENSIONS)
        for lang_key in langs
    }

    language_layout = any((video_root / name).is_dir() for name in LANG_DIRS.values())
    legacy_videos: dict[str, Path] = {}
    if not language_layout:
        legacy_videos = list_by_stem(video_root, VIDEO_EXTENSIONS)
        if not legacy_videos:
            raise MixError(f"No video files in {video_root}")
        print(
            f"[warn] legacy flat video layout in {video_root}; "
            "prefer Video/Chinese/ and Video/English/",
            file=sys.stderr,
        )

    jobs: list[MixJob] = []
    for lang_key in langs:
        in_name = LANG_DIRS[lang_key]
        video_dir = video_root / in_name
        if language_layout:
            if not video_dir.is_dir():
                print(f"[skip] {lang_key}: missing video folder {video_dir}", file=sys.stderr)
                continue
            videos = list_by_stem(video_dir, VIDEO_EXTENSIONS)
            if not videos:
                print(f"[skip] {lang_key}: no video files in {video_dir}", file=sys.stderr)
                continue
        else:
            videos = legacy_videos

        for shot_id in sorted(videos.keys()):
            video = videos[shot_id]
            audio = audio_maps[lang_key].get(shot_id)
            if audio is None:
                print(
                    f"[skip] {shot_id} {lang_key}: no VO in {in_name}/",
                    file=sys.stderr,
                )
                continue
            out_dir = output_root / in_name
            output = out_dir / f"{shot_id}{video.suffix.lower()}"
            if output.resolve() == video.resolve():
                raise MixError(
                    f"Output would overwrite input video: {video}. "
                    "Choose a different --output directory."
                )
            jobs.append(
                MixJob(
                    shot_id=shot_id,
                    lang=lang_key,
                    video=video,
                    audio=audio,
                    output=output,
                )
            )
    return jobs


def mux_job(
    ffmpeg: Path,
    ffprobe: Path,
    job: MixJob,
) -> None:
    """Retime video to VO duration; preserve source video encode + tags."""
    vo_dur = probe_duration_seconds(ffprobe, job.audio)
    vid_dur = probe_duration_seconds(ffprobe, job.video)
    ratio = vo_dur / vid_dur
    vprobe = probe_video(ffprobe, job.video)

    job.output.parent.mkdir(parents=True, exist_ok=True)

    vf = (
        f"setpts=PTS*{ratio:.12f},"
        f"tpad=stop_mode=clone:stop_duration=1"
    )
    video_args = video_encode_args(vprobe)
    audio_args = audio_encode_args(ffprobe, job.audio, job.video.suffix)
    audio_lang = "chi" if job.lang == "chinese" else "eng"

    cmd = [
        str(ffmpeg),
        "-y",
        "-i",
        str(job.video),
        "-i",
        str(job.audio),
        "-filter:v",
        vf,
        "-map",
        "0:v:0",
        "-map",
        "1:a:0",
        "-map_metadata",
        "0",
        "-map_metadata:s:v:0",
        "0:s:v:0",
        *video_args,
        *audio_args,
        "-metadata:s:a:0",
        f"language={audio_lang}",
        "-shortest",
    ]
    if job.output.suffix.lower() in {".mp4", ".m4v", ".mov"}:
        cmd.extend(["-movflags", "+faststart"])
    cmd.append(str(job.output))

    encode_note = (
        f"{vprobe.codec_name}/{vprobe.pix_fmt}"
        + (f" @{vprobe.bit_rate // 1000}kbps" if vprobe.bit_rate else "")
    )
    print(
        f"[{job.lang}] {job.shot_id}: video {vid_dur:.3f}s → {vo_dur:.3f}s "
        f"(setpts×{ratio:.6f}, {encode_note}) → "
        f"{job.output.relative_to(job.output.parent.parent)}"
    )

    result = run_cmd(cmd)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg failed for {job.shot_id} ({job.lang}):\n"
            f"{result.stderr.strip() or result.stdout.strip()}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Retime each shot video to VO duration (audio master, video only) "
            "and write <output>/Chinese/ + <output>/English/."
        )
    )
    parser.add_argument(
        "--audio",
        type=Path,
        required=True,
        help="VO work dir containing Chinese/ and English/",
    )
    parser.add_argument(
        "--video",
        type=Path,
        required=True,
        help="Video root containing Chinese/ and English/ clip folders",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output root (default: <audio>/Video)",
    )
    parser.add_argument(
        "--lang",
        choices=("both", "chinese", "english"),
        default="both",
        help="Which VO language(s) to mux (default: both)",
    )
    return parser.parse_args()


def main() -> None:
    configure_utf8_stdio()
    args = parse_args()

    try:
        root = require_dir(args.audio, "Audio dir")
        video_root = require_dir(args.video, "Video dir")
        output_root = (args.output or root / "Video").expanduser().resolve()
        print(f"Audio: {root}")
        print(f"Video: {video_root}")
        print(f"Output: {output_root}")
        jobs = build_jobs(root, args.lang, video_root, output_root)
    except MixError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    if not jobs:
        print("No mix jobs to run.", file=sys.stderr)
        sys.exit(1)

    ffmpeg = resolve_ffmpeg(Path(__file__))
    ffprobe = resolve_ffprobe(ffmpeg)

    counts = {"ok": 0, "failed": 0}
    failures: list[str] = []

    for job in jobs:
        try:
            mux_job(ffmpeg, ffprobe, job)
            counts["ok"] += 1
        except Exception as exc:  # noqa: BLE001 — continue batch; report at end
            counts["failed"] += 1
            failures.append(f"{job.shot_id}/{job.lang}: {exc}")
            print(f"[fail] {job.shot_id} {job.lang}: {exc}", file=sys.stderr)

    print(
        f"Done. ok={counts['ok']} failed={counts['failed']} output={output_root}"
    )
    if failures:
        print("Failed jobs:", file=sys.stderr)
        for line in failures:
            print(f"  {line}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
