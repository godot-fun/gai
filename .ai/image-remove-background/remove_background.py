"""
Remove background from a single image via rembg (U2Net / BiRefNet matting).

Not default python. Run through the rembg manifest bin
(Python venv at .dependency/rembg/.venv/).
Never use default python or host python/py.

Usage
-----
    .dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/foo.png
    .dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/portrait.jpg --model birefnet-portrait --alpha-matting
    .dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py --image image/hero.png -o image/hero_cutout
"""

from __future__ import annotations

import argparse
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.image_utils import image_output_name, resolve_image_file  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "image-remove-background"
DEFAULT_MODEL = "u2net"
MAX_INPUT_SIDE = 4096

MODEL_CHOICES = (
    "u2net",
    "u2netp",
    "u2net_human_seg",
    "silueta",
    "isnet-general-use",
    "birefnet-general",
    "birefnet-portrait",
)


def maybe_downscale(image: Image.Image, max_side: int) -> Image.Image:
    w, h = image.size
    longest = max(w, h)
    if longest <= max_side:
        return image
    scale = max_side / longest
    new_size = (max(1, int(w * scale)), max(1, int(h * scale)))
    return image.resize(new_size, Image.Resampling.LANCZOS)


def crop_transparent(image: Image.Image) -> Image.Image:
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    alpha = image.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def remove_background(
    source: Path,
    session,
    *,
    alpha_matting: bool,
    alpha_matting_foreground_threshold: int,
    alpha_matting_background_threshold: int,
    alpha_matting_erode_size: int,
    crop: bool,
) -> Image.Image:
    from rembg import remove

    with Image.open(source) as img:
        img = img.convert("RGBA")
        img = maybe_downscale(img, MAX_INPUT_SIDE)
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        input_bytes = buffer.getvalue()

    output_bytes = remove(
        input_bytes,
        session=session,
        alpha_matting=alpha_matting,
        alpha_matting_foreground_threshold=alpha_matting_foreground_threshold,
        alpha_matting_background_threshold=alpha_matting_background_threshold,
        alpha_matting_erode_size=alpha_matting_erode_size,
    )
    result = Image.open(BytesIO(output_bytes)).convert("RGBA")
    if crop:
        result = crop_transparent(result)
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove background from a single image with rembg and export transparent PNG."
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Path to a single image file",
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
        choices=MODEL_CHOICES,
        help=f"rembg model (default: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--alpha-matting",
        action="store_true",
        help="Enable alpha matting for softer edges (slower)",
    )
    parser.add_argument(
        "--alpha-matting-foreground-threshold",
        type=int,
        default=240,
        help="Alpha matting foreground threshold (default: 240)",
    )
    parser.add_argument(
        "--alpha-matting-background-threshold",
        type=int,
        default=10,
        help="Alpha matting background threshold (default: 10)",
    )
    parser.add_argument(
        "--alpha-matting-erode-size",
        type=int,
        default=10,
        help="Alpha matting erode size (default: 10)",
    )
    parser.add_argument(
        "--crop",
        action="store_true",
        help="Crop transparent borders after matting",
    )
    return parser.parse_args()


def main() -> int:
    configure_utf8_stdio()
    args = parse_args()

    repo_root = find_repo_root(Path(__file__))
    if repo_root is None:
        print(
            "Could not find .dependency/manifest.json. "
            "Run from a repo that follows .cursor/skills/dependency-manager.md.",
            file=sys.stderr,
        )
        return 1

    resolve_tool_bin(repo_root, "rembg")

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

    print(f"Image:  {image_path}")
    print(f"Model:  {args.model}")
    print(f"Output: {out_path}")
    print()

    from rembg import new_session

    session = new_session(args.model)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        print(f"[run]  {image_path.name} -> {out_path.name}")
        result = remove_background(
            image_path,
            session,
            alpha_matting=args.alpha_matting,
            alpha_matting_foreground_threshold=args.alpha_matting_foreground_threshold,
            alpha_matting_background_threshold=args.alpha_matting_background_threshold,
            alpha_matting_erode_size=args.alpha_matting_erode_size,
            crop=args.crop,
        )
        result.save(out_path, format="PNG")
    except Exception as exc:
        print(f"[fail] {out_path.name}")
        print(exc, file=sys.stderr)
        return 1

    print()
    print(f"Done. wrote {out_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
