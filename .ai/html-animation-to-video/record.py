#!/usr/bin/env python3
"""
Record one self-contained HTML animation to MP4 through the local web service.

The browser only plays the page. FFmpeg captures the screen with the Desktop Duplication API
(`ddagrab`) and encodes with NVENC, so nothing is ever written as a per-frame image file.

The service loads the page first (`/animation/open`) and the page stays paused on its first frame, so
browser startup, page load and fullscreen never have to fit inside the recording. Capture starts
afterwards, `/animation/play` presses Space, and the file is cut where the paused frame starts moving
— the animation's first visible frame — then kept for the declared duration.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/html-animation-to-video/record.py --html path/to/animation.html
    .dependency/python/python .ai/html-animation-to-video/record.py --html path/to/animation.html --duration 8
"""

from __future__ import annotations

import argparse
import ctypes
import json
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from ctypes import wintypes
from dataclasses import dataclass
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.cli_tools import resolve_ffmpeg, resolve_ffprobe  # noqa: E402
from common.output_utils import configure_utf8_stdio  # noqa: E402

# Every FFmpeg call here reports through its own protocol or error stream, never through stats.
QUIET = ("-hide_banner", "-loglevel", "error")
DEFAULT_HOST = "127.0.0.1"
DEFAULT_FPS = 60
# Near-transparent for a 4K60 deliverable: platforms re-encode uploads anyway, so the recorder keeps
# the margin instead of trading it for size.
QUALITY = 16
# Recorded past the animation's end: the compositor needs a frame or two to show the last change,
# and FFmpeg finishes the current frame while shutting down.
TAIL_SECONDS = 0.4
FIRST_FRAME_TIMEOUT_SECONDS = 20.0
STOP_TIMEOUT_SECONDS = 30.0
# The page stays frozen on its first frame until Space arrives, so the start of the animation is the
# first frame that moves after the press.
DETECTION_WINDOW_SECONDS = 3.0
DETECTION_LEAD_SECONDS = 0.2
# A pixel counts as changed above the encoder noise of a still frame, and a frame counts as movement
# once enough pixels changed to be visible: the paused page redraws the identical frame, so a quiet
# recording scores 0 while even a small overlay popping scores well above 0.05.
DETECTION_PIXEL_DIFFERENCE = 8
DETECTION_MIN_MOVEMENT = 0.05
# A page may open quietly: thin rules darkening, digits ticking — motion too fine to survive the
# thumbnail, so the first frame that clears the threshold can come a second after the key. The paused
# page and the animation's first frame are the same image, so such a start belongs on the press: the
# cut then keeps the whole declared timeline instead of dropping that opening and holding the last
# frame for as long as the detection was late. The limit is what the capture can still cover.
DETECTION_MAX_LEAD_SECONDS = TAIL_SECONDS - 0.15
# The analysis runs on a thumbnail: 4.6x faster at 4K, and independent of the capture resolution.
DETECTION_SCALE_WIDTH = 480
FULLSCREEN_SETTLE_SECONDS = 0.8
# Firefox animates the fullscreen transition and the page relayouts afterwards; both must finish
# before the frame that will be recorded is rendered again.
PAGE_SETTLE_SECONDS = 3.0
FULLSCREEN_ATTEMPTS = 3
FULLSCREEN_POLL_SECONDS = 0.1
FULLSCREEN_ATTEMPT_TIMEOUT_SECONDS = 2.0
STATS_PERIOD_SECONDS = 0.05
PROGRESS_PIPE = "pipe:1"

FRAME_PATTERN = re.compile(r"^frame=\s*(\d+)\s*$")
PTS_TIME_PATTERN = re.compile(r"pts_time:([0-9.]+)")
# `signalstats` prints a mean below 1e-4 in scientific notation, so the exponent has to be part of
# the value: cutting its tail turns a handful of changed pixels into a level far above the limit.
FRAME_DIFFERENCE_PATTERN = re.compile(r"lavfi\.signalstats\.YAVG=([0-9.eE+-]+)")

VK_F11 = 0x7A
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
SW_RESTORE = 9
SWP_NOSIZE = 0x0001
SWP_NOMOVE = 0x0002
SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010
HWND_TOPMOST = -1
HWND_NOTOPMOST = -2
MONITOR_DEFAULTTONEAREST = 2
MONITORINFOF_PRIMARY = 1
BROWSER_WINDOW_CLASSES = ("MozillaWindowClass", "Chrome_WidgetWin_1")
# An unset DPI awareness makes Windows virtualize every window coordinate, so at a 150% display scale
# the monitor looks like 2560x1440 and the ddagrab crop would keep only the top-left third of the 4K screen.
DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
DPI_AWARENESS_PER_MONITOR_AWARE = 2
WINDOW_APPEAR_TIMEOUT_SECONDS = 15.0
WINDOW_POLL_SECONDS = 0.1


class RecordError(RuntimeError):
    pass


@dataclass(frozen=True)
class Encoder:
    """One FFmpeg video encoder and the settings that fit it."""

    name: str
    quality_options: tuple[str, ...]
    fast_preset: str
    final_preset: str


# Hardware first, because 4K60 capture has to keep up with the screen; x264 is the last resort.
GPU_ENCODERS = (
    Encoder("hevc_nvenc", ("-rc", "vbr", "-cq"), "p1", "p4"),
    Encoder("h264_nvenc", ("-rc", "vbr", "-cq"), "p1", "p4"),
)
CPU_ENCODER = Encoder("libx264", ("-crf",), "ultrafast", "medium")


@dataclass(frozen=True)
class Monitor:
    index: int
    x: int
    y: int
    width: int
    height: int
    primary: bool = False


@dataclass(frozen=True)
class Capture:
    """Screen rectangle to record, in desktop coordinates."""

    x: int
    y: int
    width: int
    height: int


@dataclass(frozen=True)
class OpenResult:
    """The page is loaded and paused on its first frame, ready for the start key."""

    animation: str
    title: str
    duration_seconds: float


@dataclass(frozen=True)
class PlayResult:
    animation: str
    played_wall_clock_ms: float


@dataclass(frozen=True)
class VideoInfo:
    width: int
    height: int
    fps: float
    duration_seconds: float


# ---------------------------------------------------------------------------------------------------------------------
# Service HTTP


def read_env(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values


def resolve_server_url(web_directory: Path | None = None) -> str:
    web_directory = web_directory or Path(__file__).resolve().parents[2] / "web"
    configured = read_env(web_directory / ".env")
    example = read_env(web_directory / ".env.example")
    host = configured.get("HOST") or example.get("HOST") or DEFAULT_HOST
    port = configured.get("PORT") or example.get("PORT")
    if not port:
        raise RecordError("PORT is missing from web/.env and web/.env.example")
    return f"http://{host}:{port}"


def post_json(server_url: str, endpoint: str, payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        f"{server_url}{endpoint}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            value = json.load(response)
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode("utf-8"))
            detail = body.get("error", {}).get("message", str(exc))
        except (UnicodeDecodeError, json.JSONDecodeError, AttributeError):
            detail = str(exc)
        raise RecordError(detail) from exc
    except urllib.error.URLError as exc:
        raise RecordError(f"Cannot connect to the animation service at {server_url}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise RecordError("Animation service returned invalid JSON") from exc
    if not isinstance(value, dict):
        raise RecordError("Animation service returned an invalid response")
    return value


def require_animation(value: dict[str, Any]) -> str:
    animation = value.get("animation")
    if not isinstance(animation, str) or not animation:
        raise RecordError("Animation service did not return an animation name")
    return animation


def require_number(value: Any, name: str) -> float:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise RecordError(f"Animation service did not return {name}")
    return float(value)


def open_animation(server_url: str, html_path: Path, duration_seconds: float | None = None) -> OpenResult:
    """Loads the page and waits for it to be paused on its first frame, ready for the start key."""
    payload: dict[str, Any] = {"htmlPath": str(html_path)}
    if duration_seconds is not None:
        payload["duration"] = duration_seconds
    value = post_json(server_url, "/animation/open", payload)
    animation = require_animation(value)
    title = value.get("title")
    if not isinstance(title, str):
        raise RecordError("Animation service did not return the page title")
    duration_seconds = require_number(value.get("durationMs"), "durationMs") / 1000.0
    if duration_seconds <= 0:
        raise RecordError("Animation service did not return a positive durationMs")
    return OpenResult(animation=animation, title=title, duration_seconds=duration_seconds)


def close_animation(server_url: str) -> None:
    """Closes the playback tab; a failure only warns, because cleanup must not hide the real error."""
    try:
        post_json(server_url, "/animation/close", {})
    except RecordError as exc:
        print(f"[warn] Could not close the animation tab: {exc}", file=sys.stderr)


def play_animation(server_url: str) -> PlayResult:
    """Presses Space in the open page; the returned wall clock is where the animation begins."""
    value = post_json(server_url, "/animation/play", {})
    return PlayResult(
        animation=require_animation(value),
        played_wall_clock_ms=require_number(value.get("playedWallClockMs"), "playedWallClockMs"),
    )


# ---------------------------------------------------------------------------------------------------------------------
# Paths


def resolve_output_directory(args_output: str | None, html_path: Path) -> Path:
    """`--output` when given, otherwise the directory that holds the HTML file."""
    return Path(args_output).expanduser().resolve() if args_output else html_path.parent


# ---------------------------------------------------------------------------------------------------------------------
# FFmpeg


def encoder_options(encoder: Encoder, preset: str, fps: int) -> list[str]:
    """Encoder settings shared by the capture and the final encode."""
    return [
        "-c:v", encoder.name,
        "-preset", preset,
        *encoder.quality_options, str(QUALITY),
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-fps_mode", "cfr",
    ]


def pick_encoder(ffmpeg: Path) -> Encoder:
    """The first GPU encoder the driver answers for, otherwise the CPU encoder."""
    for encoder in GPU_ENCODERS:
        if encoder_available(ffmpeg, encoder.name):
            return encoder
    print("[warn] No NVENC encoder is available; falling back to CPU x264", file=sys.stderr)
    return CPU_ENCODER


def encoder_available(ffmpeg: Path, name: str) -> bool:
    """Encodes one tiny frame, which proves the encoder exists and its hardware answers."""
    result = subprocess.run(
        [
            str(ffmpeg), *QUIET,
            "-f", "lavfi", "-i", "color=c=black:s=256x144:r=30:d=0.1",
            "-c:v", name, "-f", "null", "-",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.returncode == 0


def build_record_command(
    ffmpeg: Path,
    monitor: Monitor,
    capture: Capture,
    fps: int,
    encoder: Encoder,
    raw_path: Path,
) -> list[str]:
    source = (
        f"ddagrab=output_idx={monitor.index}:framerate={fps}:draw_mouse=0"
        f":video_size={capture.width}x{capture.height}"
        f":offset_x={capture.x - monitor.x}:offset_y={capture.y - monitor.y}"
    )
    return [
        str(ffmpeg),
        *QUIET,
        "-nostats",
        "-init_hw_device", "d3d11va=dda",
        "-f", "lavfi", "-i", source,
        "-vf", "hwdownload,format=bgra,format=yuv420p",
        *encoder_options(encoder, encoder.fast_preset, fps),
        "-progress", PROGRESS_PIPE,
        "-stats_period", f"{STATS_PERIOD_SECONDS}",
        "-y", str(raw_path),
    ]


def build_trim_command(
    ffmpeg: Path,
    raw_path: Path,
    output_path: Path,
    start_seconds: float,
    duration_seconds: float,
    fps: int,
    encoder: Encoder,
) -> list[str]:
    return [
        str(ffmpeg),
        *QUIET,
        "-nostats",
        "-ss", f"{max(0.0, start_seconds):.3f}",
        "-i", str(raw_path),
        "-t", f"{max(0.0, duration_seconds):.3f}",
        *encoder_options(encoder, encoder.final_preset, fps),
        "-an",
        "-movflags", "+faststart",
        "-y", str(output_path),
    ]


def parse_progress_frame(line: str) -> int | None:
    """Returns the frame count of an FFmpeg `-progress` line, or None for any other line."""
    match = FRAME_PATTERN.match(line.strip())
    return int(match.group(1)) if match is not None else None


def parse_frame_differences(text: str) -> list[tuple[float, float]]:
    """Reads `pts_time` and the changed pixel level of a `metadata=print` stream."""
    differences: list[tuple[float, float]] = []
    timestamp = 0.0
    for line in text.splitlines():
        pts = PTS_TIME_PATTERN.search(line)
        if pts is not None:
            timestamp = float(pts.group(1))
            continue
        difference = FRAME_DIFFERENCE_PATTERN.search(line)
        if difference is not None:
            differences.append((timestamp, float(difference.group(1))))
    return differences


def find_first_movement(differences: list[tuple[float, float]]) -> float | None:
    """The first timestamp whose frame visibly differs from the one before it."""
    for timestamp, movement in differences:
        if movement > DETECTION_MIN_MOVEMENT:
            return timestamp
    return None


def detect_animation_start(
    ffmpeg: Path,
    raw_path: Path,
    search_start_seconds: float,
    window_seconds: float,
) -> float | None:
    """Finds the frame where the paused page starts moving, in seconds of the raw recording."""
    start = max(0.0, search_start_seconds)
    command = [
        str(ffmpeg),
        *QUIET,
        "-ss", f"{start:.3f}",
        "-i", str(raw_path),
        "-t", f"{max(0.0, window_seconds):.3f}",
        "-vf",
        f"scale={DETECTION_SCALE_WIDTH}:-2,format=gray,tblend=all_mode=difference,"
        f"geq=lum='if(gt(lum(X,Y),{DETECTION_PIXEL_DIFFERENCE}),255,0)',"
        "signalstats,metadata=print:file=-",
        "-f", "null", "-",
    ]
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        detail = (result.stderr or "").strip()[-300:] or "FFmpeg failed without diagnostics"
        print(f"[warn] Could not analyse the recording: {detail}", file=sys.stderr)
        return None
    found = find_first_movement(parse_frame_differences(result.stdout))
    return None if found is None else start + found


def now_ms() -> float:
    return time.time() * 1000.0


def wait_until_ms(deadline_ms: float) -> None:
    """Sleeps until the wall clock reaches `deadline_ms`; a deadline already passed returns at once."""
    remaining = (deadline_ms - now_ms()) / 1000.0
    if remaining > 0:
        time.sleep(remaining)


class ScreenRecorder:
    """Runs one FFmpeg screen capture and remembers when its first frame was captured."""

    def __init__(self, command: list[str], raw_path: Path) -> None:
        self.command = command
        self.raw_path = raw_path
        self.process: subprocess.Popen[str] | None = None
        self.first_frame_ms: float | None = None
        self.lines: list[str] = []
        self._first_frame_event = threading.Event()

    def start(self) -> None:
        # Progress and log lines share one pipe, so a single reader thread covers both.
        self.process = subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        threading.Thread(target=self.read_output, daemon=True).start()

    def read_output(self) -> None:
        process = self.process
        if process is None or process.stdout is None:
            return
        for line in process.stdout:
            self.lines.append(line.rstrip())
            frame = parse_progress_frame(line)
            if self.first_frame_ms is None and frame is not None and frame > 0:
                self.first_frame_ms = now_ms()
                self._first_frame_event.set()

    def diagnostics(self) -> str:
        return " | ".join(self.lines[-3:]) or "no FFmpeg diagnostics"

    def wait_first_frame(self, timeout_seconds: float = FIRST_FRAME_TIMEOUT_SECONDS) -> float:
        if not self._first_frame_event.wait(timeout_seconds):
            detail = self.diagnostics()
            self.stop()
            raise RecordError(f"FFmpeg did not capture a frame within {timeout_seconds:.0f}s: {detail}")
        return self.first_frame_ms or now_ms()

    def stop(self) -> None:
        process = self.process
        if process is None:
            return
        try:
            if process.stdin is not None:
                process.stdin.write("q")
                process.stdin.flush()
        except (BrokenPipeError, OSError):
            pass
        try:
            process.wait(timeout=STOP_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=STOP_TIMEOUT_SECONDS)
        self.process = None
        if not self.raw_path.is_file() or self.raw_path.stat().st_size == 0:
            raise RecordError(f"FFmpeg wrote no recording: {self.diagnostics()}")


def probe_video(ffprobe: Path, path: Path) -> VideoInfo:
    result = subprocess.run(
        [
            str(ffprobe),
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate:format=duration",
            "-of", "json",
            str(path),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        raise RecordError(f"ffprobe could not read: {path}")
    try:
        payload = json.loads(result.stdout)
        stream = payload["streams"][0]
        return VideoInfo(
            width=int(stream["width"]),
            height=int(stream["height"]),
            fps=parse_rate(str(stream.get("r_frame_rate", "0/1"))),
            duration_seconds=float(payload["format"]["duration"]),
        )
    except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise RecordError(f"ffprobe returned an unusable result for {path}") from exc


def parse_rate(value: str) -> float:
    numerator, _, denominator = value.partition("/")
    try:
        return float(numerator) / float(denominator or 1)
    except (ValueError, ZeroDivisionError):
        return 0.0


# ---------------------------------------------------------------------------------------------------------------------
# Windows screen and window handling

_user32: Any = None
_kernel32: Any = None


class _RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class _MONITORINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("rcMonitor", _RECT),
        ("rcWork", _RECT),
        ("dwFlags", wintypes.DWORD),
    ]


_MONITORENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_int, wintypes.HANDLE, wintypes.HDC, ctypes.POINTER(_RECT), wintypes.LPARAM)
_WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)


def win32() -> tuple[Any, Any]:
    global _user32, _kernel32
    if _user32 is None:
        if sys.platform != "win32":
            raise RecordError("Screen capture is supported only on Windows")
        _user32 = ctypes.WinDLL("user32", use_last_error=True)
        _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        enable_dpi_awareness(_user32)
    return _user32, _kernel32


def enable_dpi_awareness(user32: Any) -> None:
    """Reports physical pixels for window and monitor rectangles, matching what ddagrab captures."""
    try:
        user32.SetProcessDpiAwarenessContext.argtypes = [wintypes.HANDLE]
        user32.SetProcessDpiAwarenessContext.restype = wintypes.BOOL
        if user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)):
            return
    except (AttributeError, OSError, ctypes.ArgumentError):
        pass
    try:
        shcore = ctypes.WinDLL("shcore", use_last_error=True)
        shcore.SetProcessDpiAwareness(DPI_AWARENESS_PER_MONITOR_AWARE)
    except (AttributeError, OSError):
        pass


def enum_monitors() -> list[Monitor]:
    """Monitors ordered left to right, and numbered the way `ddagrab=output_idx` numbers them."""
    user32, _ = win32()
    found: list[tuple[int, int, int, int, bool]] = []

    def callback(hmonitor: Any, _hdc: Any, _rect: Any, _param: Any) -> int:
        info = _MONITORINFO()
        info.cbSize = ctypes.sizeof(_MONITORINFO)
        if user32.GetMonitorInfoW(hmonitor, ctypes.byref(info)):
            bounds = info.rcMonitor
            found.append((
                bounds.left,
                bounds.top,
                bounds.right - bounds.left,
                bounds.bottom - bounds.top,
                bool(info.dwFlags & MONITORINFOF_PRIMARY),
            ))
        return 1

    if not user32.EnumDisplayMonitors(None, None, _MONITORENUMPROC(callback), 0):
        raise RecordError("Could not enumerate the monitors")
    found.sort(key=lambda item: (item[0], item[1]))
    return [
        Monitor(index=index, x=x, y=y, width=width, height=height, primary=primary)
        for index, (x, y, width, height, primary) in enumerate(found)
    ]


def list_browser_windows() -> list[tuple[int, str]]:
    """Visible browser windows as (handle, title), in window enumeration order."""
    user32, _ = win32()
    candidates: list[tuple[int, str]] = []

    def callback(hwnd: Any, _param: Any) -> bool:
        if not user32.IsWindowVisible(hwnd):
            return True
        class_name = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, class_name, 256)
        if class_name.value not in BROWSER_WINDOW_CLASSES:
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        title = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, title, length + 1)
        candidates.append((int(hwnd), title.value))
        return True

    user32.EnumWindows(_WNDENUMPROC(callback), 0)
    return candidates


def browser_window(title_hint: str, timeout_seconds: float = 0.0) -> int:
    """The browser window showing the animation: waits for its title, then settles for any browser.

    The wait exists because the service opens the tab in the background after answering.
    """
    hint = title_hint.strip()
    deadline = time.monotonic() + timeout_seconds
    while True:
        windows = list_browser_windows()
        for hwnd, title in windows:
            if hint and hint in title:
                return hwnd
        if time.monotonic() >= deadline:
            break
        time.sleep(WINDOW_POLL_SECONDS)
    if not windows:
        raise RecordError("No browser window found: start the gai web service and keep the browser open")
    return windows[0][0]


def window_capture(hwnd: int) -> Capture:
    user32, _ = win32()
    client = _RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(client)):
        raise RecordError("Could not read the browser window size")
    origin = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    width = client.right - client.left
    height = client.bottom - client.top
    # yuv420p needs even sides: an odd window size would round up in the encoder and never match the crop.
    return Capture(x=origin.x, y=origin.y, width=width - width % 2, height=height - height % 2)


def capture_within(capture: Capture, monitor: Monitor) -> bool:
    """Whether the recorded rectangle lies inside the monitor it will be cropped from."""
    return (
        capture.x >= monitor.x
        and capture.y >= monitor.y
        and capture.x + capture.width <= monitor.x + monitor.width
        and capture.y + capture.height <= monitor.y + monitor.height
    )


def is_on_monitor(hwnd: int, monitor: Monitor) -> bool:
    """Whether the window currently sits on `monitor`; unknown answers count as "not there"."""
    user32, _ = win32()
    info = _MONITORINFO()
    info.cbSize = ctypes.sizeof(_MONITORINFO)
    if not user32.GetMonitorInfoW(user32.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), ctypes.byref(info)):
        return False
    bounds = info.rcMonitor
    return (bounds.left, bounds.top) == (monitor.x, monitor.y)


def force_foreground(hwnd: int) -> None:
    """Brings the window forward even when another application owns the foreground."""
    user32, kernel32 = win32()
    if user32.GetForegroundWindow() == hwnd:
        return
    target_thread = user32.GetWindowThreadProcessId(hwnd, None)
    current_thread = kernel32.GetCurrentThreadId()
    user32.AttachThreadInput(current_thread, target_thread, True)
    try:
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
    finally:
        user32.AttachThreadInput(current_thread, target_thread, False)


def focus_window(hwnd: int) -> None:
    """Restores and raises the window, even when Windows keeps the foreground on another process."""
    user32, _ = win32()
    user32.ShowWindow(hwnd, SW_RESTORE)
    force_foreground(hwnd)
    # A trip through the topmost band raises the window in z-order without needing the foreground,
    # so another application cannot end up covering the page the recorder is capturing.
    flags = SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, flags)
    user32.SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, flags)


def move_window_to_monitor(hwnd: int, monitor: Monitor) -> None:
    user32, _ = win32()
    user32.SetWindowPos(hwnd, None, monitor.x, monitor.y, monitor.width, monitor.height, SWP_NOZORDER | SWP_NOACTIVATE)


def send_f11(hwnd: int) -> None:
    """Posts F11 to the window itself: a posted key works while Windows still refuses it the foreground."""
    user32, _ = win32()
    user32.PostMessageW(hwnd, WM_KEYDOWN, VK_F11, 0)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_KEYUP, VK_F11, 0)


def covers_monitor(hwnd: int, monitor: Monitor) -> bool:
    """Whether the window client area is exactly one monitor big, wherever that monitor is."""
    capture = window_capture(hwnd)
    return (capture.width, capture.height) == (monitor.width, monitor.height)


def is_fullscreen(hwnd: int, monitor: Monitor) -> bool:
    """Fullscreen *and* on the recorded monitor: two identical displays would fool a size check."""
    return covers_monitor(hwnd, monitor) and is_on_monitor(hwnd, monitor)


def ensure_fullscreen(hwnd: int, monitor: Monitor) -> bool:
    """Switches the browser to browser-fullscreen so the page owns the whole monitor.

    A window that was just restored ignores F11 while the shell is still animating it, and a second
    press on an already fullscreen window would leave fullscreen again, so every attempt re-checks.
    """
    for _attempt in range(FULLSCREEN_ATTEMPTS):
        if is_fullscreen(hwnd, monitor):
            return True
        focus_window(hwnd)
        time.sleep(FULLSCREEN_SETTLE_SECONDS)
        if is_fullscreen(hwnd, monitor):
            return True
        send_f11(hwnd)
        deadline = time.monotonic() + FULLSCREEN_ATTEMPT_TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            time.sleep(FULLSCREEN_POLL_SECONDS)
            if is_fullscreen(hwnd, monitor):
                return True
    return is_fullscreen(hwnd, monitor)


def leave_fullscreen(monitor: Monitor) -> None:
    """Leaves browser fullscreen on `monitor` so the display goes back to the desktop."""
    for hwnd, _title in list_browser_windows():
        if is_fullscreen(hwnd, monitor):
            send_f11(hwnd)
            return


def resolve_monitor() -> Monitor:
    """The secondary display: recording stays off the screen the user is working on."""
    monitors = enum_monitors()
    if not monitors:
        raise RecordError("No display is available for recording")
    for monitor in monitors:
        if not monitor.primary:
            return monitor
    print("[warn] Only one display is attached; recording the primary display", file=sys.stderr)
    return monitors[0]


def place_window(hwnd: int, monitor: Monitor) -> Capture:
    """Moves the browser onto the recorded monitor, then switches it to browser fullscreen."""
    focus_window(hwnd)
    if is_fullscreen(hwnd, monitor):
        return window_capture(hwnd)
    if covers_monitor(hwnd, monitor):
        # Fullscreen on another display: leave it first, or the window manager ignores the move.
        send_f11(hwnd)
        time.sleep(FULLSCREEN_SETTLE_SECONDS)
    move_window_to_monitor(hwnd, monitor)
    time.sleep(0.4)
    if not ensure_fullscreen(hwnd, monitor):
        print("[warn] Browser window is not fullscreen; recording its client area instead of the monitor", file=sys.stderr)
    return window_capture(hwnd)


# ---------------------------------------------------------------------------------------------------------------------
# Flow


def prepare_stage(server_url: str, html_path: Path, duration_seconds: float | None) -> tuple[Monitor, Capture, OpenResult]:
    """Opens the page, moves the browser onto the secondary display and switches it to fullscreen.

    Browser startup, page load, fullscreen and the page's own title and duration all happen before
    capture: the page stays paused on its first frame until Space arrives, so only the Space press
    has to fit inside the recording.
    """
    monitor = resolve_monitor()
    opening = open_animation(server_url, html_path, duration_seconds)
    print(f"[open] {opening.animation} (paused on the first frame)", flush=True)
    hwnd = browser_window(opening.title, WINDOW_APPEAR_TIMEOUT_SECONDS)
    rendered = window_capture(hwnd)
    capture = place_window(hwnd, monitor)
    print(f"[window] {capture.width}x{capture.height} at {capture.x},{capture.y} on display {monitor.index} (secondary)", flush=True)
    if not capture_within(capture, monitor):
        raise RecordError(
            f"The browser window is {capture.width}x{capture.height} at {capture.x},{capture.y}, "
            f"outside display {monitor.index}: move it there and record again"
        )
    print(f"[window] waiting {PAGE_SETTLE_SECONDS:.0f}s for the page to settle", flush=True)
    time.sleep(PAGE_SETTLE_SECONDS)
    # Reopening after a resize renders the paused first frame at the final size, so the recorded frame
    # before the start key matches the first frame of the animation. Same size already? Skip it.
    if (rendered.width, rendered.height) != (capture.width, capture.height):
        opening = open_animation(server_url, html_path, duration_seconds)
        print(f"[open] {opening.animation} (rendered at {capture.width}x{capture.height})", flush=True)
    return monitor, capture, opening


def record_screen(recorder: ScreenRecorder, server_url: str, duration_seconds: float) -> float:
    """Presses Space once capture is running, and stops after the animation has been fully recorded.

    Returns how far into the recording the press landed, in seconds.
    """
    recorder.start()
    first_frame_ms = recorder.wait_first_frame()
    print("[record] capturing", flush=True)
    start = play_animation(server_url)
    pressed_seconds = max(0.0, (start.played_wall_clock_ms - first_frame_ms) / 1000.0)
    print(f"[play] {start.animation} (Space pressed at {pressed_seconds:.3f}s)", flush=True)
    wait_until_ms(start.played_wall_clock_ms + (duration_seconds + TAIL_SECONDS) * 1000.0)
    recorder.stop()
    print("[record] finished", flush=True)
    return pressed_seconds


def find_animation_start(ffmpeg: Path, raw_path: Path, pressed_seconds: float) -> float:
    """The first frame that moves, in seconds of the raw recording; falls back to the key press.

    The paused page is still until Space arrives, so the first frame that differs from the frame
    before it is the animation starting on screen. Its own timestamp is used instead of the press,
    which the compositor and the capture pipeline delay by an unpredictable amount. A start too
    late to leave the whole timeline inside the capture falls back to the press: that opening is
    the animation itself, only too fine for the thumbnail to see.
    """
    detected = detect_animation_start(
        ffmpeg,
        raw_path,
        max(0.0, pressed_seconds - DETECTION_LEAD_SECONDS),
        DETECTION_WINDOW_SECONDS,
    )
    if detected is None:
        print("[warn] Could not find the first moving frame; cutting at the Space press instead", file=sys.stderr)
        return pressed_seconds
    lead_seconds = detected - pressed_seconds
    if lead_seconds > DETECTION_MAX_LEAD_SECONDS:
        print(
            f"[warn] The page first moves {lead_seconds:.2f}s after the key; cutting at the press to keep the timeline",
            file=sys.stderr,
        )
        return pressed_seconds
    return detected


def record(args: argparse.Namespace) -> Path:
    configure_utf8_stdio()
    started_at = time.perf_counter()
    html_path = Path(args.html).expanduser().resolve()
    if not html_path.is_file():
        raise RecordError(f"HTML file not found: {html_path}")
    output_directory = resolve_output_directory(args.output, html_path)
    output_directory.mkdir(parents=True, exist_ok=True)
    output_path = output_directory / f"{html_path.stem}.mp4"
    raw_path = output_directory / f"{html_path.stem}.raw.mp4"

    ffmpeg = resolve_ffmpeg(Path(__file__))
    ffprobe = resolve_ffprobe(ffmpeg)
    server_url = resolve_server_url()
    encoder = pick_encoder(ffmpeg)

    monitor, capture, opening = prepare_stage(server_url, html_path, args.duration)
    try:
        duration_seconds = opening.duration_seconds
        recorder = ScreenRecorder(build_record_command(ffmpeg, monitor, capture, args.fps, encoder, raw_path), raw_path)
        pressed_seconds = record_screen(recorder, server_url, duration_seconds)
        lead_seconds = find_animation_start(ffmpeg, raw_path, pressed_seconds)

        print(f"[trim] keeping {duration_seconds:.3f}s from {lead_seconds:.3f}s", flush=True)
        trim = subprocess.run(
            build_trim_command(ffmpeg, raw_path, output_path, lead_seconds, duration_seconds, args.fps, encoder),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if trim.returncode != 0:
            detail = (trim.stderr or "").strip()[-500:] or "FFmpeg failed without diagnostics"
            raise RecordError(f"Trimming the recording failed: {detail}")

        video = verify_output(ffprobe, output_path, capture, args.fps, duration_seconds)
    finally:
        # Leave the desktop as it was found, whether or not the recording worked.
        close_animation(server_url)
        leave_fullscreen(monitor)

    # Keep the untrimmed recording when verification fails: it is the only way to see what went wrong.
    raw_path.unlink(missing_ok=True)
    print("[completed]")
    print(f"File:       {output_path}")
    print(f"Resolution: {video.width}x{video.height}")
    print(f"FPS:        {video.fps:.3f}")
    print(f"Duration:   {video.duration_seconds:.3f} s")
    print(f"Source:     display {monitor.index} (secondary) · {encoder.name} quality {QUALITY}")
    print(f"Elapsed:    {time.perf_counter() - started_at:.1f} s")
    return output_path


def verify_output(ffprobe: Path, path: Path, capture: Capture, fps: int, duration_seconds: float) -> VideoInfo:
    if not path.is_file() or path.stat().st_size == 0:
        raise RecordError(f"Output is missing or empty: {path}")
    video = probe_video(ffprobe, path)
    if (video.width, video.height) != (capture.width, capture.height):
        raise RecordError(
            f"Recorded {video.width}x{video.height}, expected {capture.width}x{capture.height}: "
            "the browser window moved during recording"
        )
    if abs(video.fps - fps) > 0.01:
        raise RecordError(f"Recorded {video.fps:.3f} fps, expected {fps} fps")
    frame_duration = 1.0 / fps
    if abs(video.duration_seconds - duration_seconds) > frame_duration * 2:
        raise RecordError(f"Recorded {video.duration_seconds:.3f} s, expected {duration_seconds:.3f} s")
    return video


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Record an HTML animation to MP4 by screen capture")
    parser.add_argument("--html", required=True, help="Path to the self-contained HTML animation")
    parser.add_argument("--output", default=None, help="Directory for the recorded MP4 (default: the HTML file's directory)")
    parser.add_argument("--duration", type=float, default=None, help="Override the animation-duration meta tag")
    parser.add_argument("--fps", type=int, default=DEFAULT_FPS, help=f"Capture frame rate (default {DEFAULT_FPS})")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        record(args)
    except RecordError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[stopped] Interrupted", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
