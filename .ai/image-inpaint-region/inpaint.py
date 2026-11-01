"""
Inpaint a region of a single image with LaMa (IOPaint).

Not default python. Run through the iopaint manifest bin
(Python 3.11 venv at .dependency/iopaint/.venv/).
Never use default python or host python/py.

Mask handling and InpaintRequest defaults follow IOPaint batch_processing / API.

Usage
-----
    .dependency/iopaint/.venv/Scripts/python.exe .ai/image-inpaint-region/inpaint.py --image image/foo.png --region 148,248,48
    .dependency/iopaint/.venv/Scripts/python.exe .ai/image-inpaint-region/inpaint.py --image image/foo.png --region 148,248,48 --device cuda -o image/out
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.image_utils import image_output_name, resolve_image_file  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "image-inpaint-region"
DEFAULT_MODEL = "lama"
DEFAULT_DEVICE = "cpu"


def parse_circle_region(region: str) -> tuple[float, float, float] | None:
    parts = [part.strip() for part in region.split(",")]
    if len(parts) != 3:
        return None
    try:
        cx, cy, radius = (float(part) for part in parts)
    except ValueError:
        return None
    if radius <= 0:
        return None
    return cx, cy, radius


def make_circle_mask(
    image_width: int,
    image_height: int,
    cx: float,
    cy: float,
    radius: float,
) -> np.ndarray:
    """Build a grayscale mask image; IOPaint binarizes at 127 before inference."""
    mask = Image.new("L", (image_width, image_height), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=255,
    )
    return np.array(mask, dtype=np.uint8)


def binarize_mask(mask_img: np.ndarray) -> np.ndarray:
    """Same threshold as iopaint.batch_processing and iopaint.api."""
    mask_img = mask_img.copy()
    mask_img[mask_img >= 127] = 255
    mask_img[mask_img < 127] = 0
    return mask_img


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inpaint a circular region of a single image with LaMa (IOPaint).",
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Path to a single image file",
    )
    parser.add_argument(
        "--region",
        required=True,
        help="Circular inpaint region as cx,cy,r in pixels (center x, center y, radius)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="",
        help=(
            "Output PNG file or directory. "
            f"Default: {format_default_output_help(DEFAULT_OUTPUT_SUBDIR, output_name_label='source-name.png')}"
        ),
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"IOPaint model (default: {DEFAULT_MODEL}, same as iopaint run)",
    )
    parser.add_argument(
        "--device",
        choices=("cuda", "cpu"),
        default=DEFAULT_DEVICE,
        help="Inference device (default: cpu, same as iopaint run / start)",
    )
    return parser.parse_args()


def main() -> int:
    configure_utf8_stdio()
    args = parse_args()

    try:
        from iopaint.helper import pil_to_bytes
        from iopaint.model.utils import torch_gc
        from iopaint.model_manager import ModelManager
        from iopaint.runtime import check_device
        from iopaint.schema import Device, InpaintRequest
    except ImportError:
        print(
            "Run this script with the iopaint venv interpreter:\n"
            "  .dependency/iopaint/.venv/Scripts/python.exe "
            ".ai/image-inpaint-region/inpaint.py --image <path> --region cx,cy,r",
            file=sys.stderr,
        )
        return 1

    repo_root = find_repo_root(Path(__file__))
    if repo_root is None:
        print(
            "Could not find .dependency/manifest.json. "
            "Run from a repo that follows .cursor/skills/dependency-manager.md.",
            file=sys.stderr,
        )
        return 1

    resolve_tool_bin(repo_root, "iopaint")

    circle = parse_circle_region(args.region)
    if circle is None:
        print(
            f"Invalid --region {args.region!r}. Use cx,cy,r in pixels (center x, center y, radius).",
            file=sys.stderr,
        )
        return 1

    cx, cy, radius = circle

    image_path = resolve_image_file(args.image)
    if image_path is None:
        return 1

    out_path = resolve_output_path(
        args.output,
        image_path,
        DEFAULT_OUTPUT_SUBDIR,
        image_output_name(image_path, suffix=".png"),
    )

    if out_path.resolve() == image_path.resolve():
        print(
            "Refusing to overwrite source file. Choose a separate output path "
            f"(default: {DEFAULT_OUTPUT_SUBDIR}/).",
            file=sys.stderr,
        )
        return 1

    if out_path.exists():
        print(f"Output already exists: {out_path}", file=sys.stderr)
        return 1

    device = check_device(Device(args.device))
    print(f"Image:  {image_path}")
    print(f"Model:  {args.model}")
    print(f"Device: {device.value}")
    print(f"Region: center=({cx:g}, {cy:g}) radius={radius:g}")
    print(f"Output: {out_path}")
    print()

    inpaint_request = InpaintRequest()
    model_manager = ModelManager(name=args.model, device=torch.device(device.value))
    out_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        print(f"[run]  {image_path.name} -> {out_path.name}")
        source = Image.open(image_path)
        infos = source.info
        img = np.array(source.convert("RGB"))
        width, height = img.shape[:2]
        mask_img = make_circle_mask(width, height, cx, cy, radius)
        mask_img = binarize_mask(mask_img)

        inpaint_result = model_manager(img, mask_img, inpaint_request)
        inpaint_result = cv2.cvtColor(inpaint_result, cv2.COLOR_BGR2RGB)
        payload = pil_to_bytes(Image.fromarray(inpaint_result), "png", 100, infos)
        out_path.write_bytes(payload)
        print(f"  circle center=({cx:g}, {cy:g}) r={radius:g}")
    except Exception as exc:
        print(f"[fail] {out_path.name}")
        print(exc, file=sys.stderr)
        return 1
    finally:
        torch_gc()

    print()
    print(f"Done. wrote {out_path.name}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
