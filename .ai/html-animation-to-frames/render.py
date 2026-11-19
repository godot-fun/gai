#!/usr/bin/env python3
"""
Render one HTML animation into PNG frames through the local web API.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python.exe .ai/html-animation-to-frames/render.py --html path/to/animation.html --output path/to/frames
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

POLL_INTERVAL_SECONDS = 2
DEFAULT_HOST = "127.0.0.1"


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
        raise RuntimeError("PORT is missing from web/.env and web/.env.example")
    return f"http://{host}:{port}"


SERVER_URL = resolve_server_url()


class RenderError(RuntimeError):
    pass


def post_json(endpoint: str, payload: dict[str, str]) -> dict[str, Any]:
    request = urllib.request.Request(
        f"{SERVER_URL}{endpoint}",
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
        raise RenderError(detail) from exc
    except urllib.error.URLError as exc:
        raise RenderError(f"Cannot connect to animation service at {SERVER_URL}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise RenderError("Animation service returned invalid JSON") from exc

    if not isinstance(value, dict):
        raise RenderError("Animation service returned an invalid response")
    return value


def create_animation(html: str, output: str) -> str:
    response = post_json("/animation/create", {"htmlPath": html, "outputDirectory": output})
    animation = response.get("animation")
    if not isinstance(animation, str) or not animation:
        raise RenderError("Animation service did not return an animation name")
    return animation


def wait_for_animation(animation: str, output: str) -> None:
    while True:
        response = post_json(
            "/animation/query",
            {"animation": animation, "outputDirectory": output},
        )
        status = response.get("status")
        if status == "completed":
            return
        if status == "failed":
            error = response.get("error")
            raise RenderError(error if isinstance(error, str) and error else "Animation rendering failed")
        if status != "rendering":
            raise RenderError(f"Animation service returned unknown status: {status}")
        print(f"[rendering] {animation}", flush=True)
        time.sleep(POLL_INTERVAL_SECONDS)


def verify_output(animation: str, output: str) -> dict[str, Any]:
    animation_directory = Path(output) / animation
    manifest_path = animation_directory / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RenderError(f"Manifest not found: {manifest_path}") from exc
    except json.JSONDecodeError as exc:
        raise RenderError(f"Manifest is invalid JSON: {manifest_path}") from exc

    if not isinstance(manifest, dict) or manifest.get("status") != "completed":
        raise RenderError("Manifest does not report a completed animation")
    total_frames = manifest.get("totalFrames")
    rendered_frames = manifest.get("renderedFrames")
    if not isinstance(total_frames, int) or total_frames <= 0:
        raise RenderError("Manifest totalFrames must be a positive integer")
    if rendered_frames != total_frames:
        raise RenderError(f"Rendered frame count is incomplete: {rendered_frames}/{total_frames}")

    frame_count = sum(1 for _ in animation_directory.glob("*.png"))
    if frame_count != total_frames:
        raise RenderError(f"PNG frame count is incomplete: {frame_count}/{total_frames}")
    first = animation_directory / "000000.png"
    last = animation_directory / f"{total_frames - 1:06d}.png"
    for frame in (first, last):
        if not frame.is_file() or frame.stat().st_size == 0:
            raise RenderError(f"Frame is missing or empty: {frame}")
    return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render an HTML animation into PNG frames")
    parser.add_argument("--html", required=True, help="Path to the HTML animation")
    parser.add_argument("--output", required=True, help="Parent output directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        animation = create_animation(args.html, args.output)
        print(f"Animation: {animation}")
        wait_for_animation(animation, args.output)
        manifest = verify_output(animation, args.output)
    except RenderError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[stopped] Waiting interrupted", file=sys.stderr)
        return 130

    print("[completed]")
    print(f"Directory:  {Path(args.output) / animation}")
    print(f"Resolution: {manifest.get('width')}x{manifest.get('height')}")
    print(f"FPS:        {manifest.get('fps')}")
    print(f"Frames:     {manifest.get('totalFrames')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
