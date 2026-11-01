"""
Trim invalid borders (transparent or solid-color padding) from a single image using Pillow.

Default crop preserves the source aspect ratio. Not default python. Run through the
image-trim manifest bin (Python venv at .dependency/image-trim/.venv/).
Never use default python or host python/py.

Usage
-----
    .dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/sprites/hero.png
    .dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/cutout.png --mode alpha
    .dependency/image-trim/.venv/Scripts/python.exe .ai/image-trim/trim.py --image image/foo.jpg --mode color --color FFFFFF --padding 4
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.image_utils import resolve_image_file  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "image-trim"
DEFAULT_MODE = "auto"
DEFAULT_ALPHA_THRESHOLD = 10
DEFAULT_TOLERANCE = 25
DEFAULT_PADDING = 0
CURSOR_ATTACHMENT_RE = re.compile(
    r"empty-window_images_(?P<name>.+)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def parse_color(value: str) -> tuple[int, int, int]:
    cleaned = value.strip().lstrip("#")
    if len(cleaned) != 6:
        raise ValueError(f"Expected 6-digit hex color, got: {value!r}")
    try:
        r = int(cleaned[0:2], 16)
        g = int(cleaned[2:4], 16)
        b = int(cleaned[4:6], 16)
    except ValueError as exc:
        raise ValueError(f"Invalid hex color: {value!r}") from exc
    return r, g, b


def color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def output_filename(source: Path) -> str:
    match = CURSOR_ATTACHMENT_RE.search(source.stem)
    if match:
        return f"{match.group('name')}{source.suffix.lower()}"
    return source.name


def prepare_image(image: Image.Image) -> Image.Image:
    if image.mode == "P":
        if image.info.get("transparency") is not None:
            return image.convert("RGBA")
        return image.convert("RGB")
    if image.mode == "LA":
        return image.convert("RGBA")
    if image.mode == "RGBA":
        return image.copy()
    return image.convert("RGB")


def has_transparency(image: Image.Image) -> bool:
    if image.mode in {"RGBA", "LA"}:
        alpha = image.split()[-1]
        return alpha.getextrema()[0] < 255
    if image.mode == "P" and image.info.get("transparency") is not None:
        return True
    return False


def sample_corner_background(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    w, h = rgb.size
    corners = [
        rgb.getpixel((0, 0)),
        rgb.getpixel((w - 1, 0)),
        rgb.getpixel((0, h - 1)),
        rgb.getpixel((w - 1, h - 1)),
    ]
    return max(set(corners), key=corners.count)


def bbox_from_alpha(image: Image.Image, threshold: int) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    alpha = rgba.split()[3]
    if threshold <= 0:
        return alpha.getbbox()

    width, height = alpha.size
    pixels = alpha.load()
    min_x, min_y = width, height
    max_x, max_y = -1, -1
    found = False
    for y in range(height):
        for x in range(width):
            if pixels[x, y] > threshold:
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if not found:
        return None
    return min_x, min_y, max_x + 1, max_y + 1


def bbox_from_color(
    image: Image.Image,
    background: tuple[int, int, int],
    tolerance: int,
    alpha_threshold: int,
) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    min_x, min_y = width, height
    max_x, max_y = -1, -1
    found = False
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a <= alpha_threshold:
                continue
            if color_distance((r, g, b), background) > tolerance:
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if not found:
        return None
    return min_x, min_y, max_x + 1, max_y + 1


def detect_content_bbox(
    image: Image.Image,
    *,
    mode: str,
    alpha_threshold: int,
    background: tuple[int, int, int] | None,
    tolerance: int,
) -> tuple[int, int, int, int] | None:
    if mode == "alpha":
        return bbox_from_alpha(image, alpha_threshold)

    if mode == "color":
        if background is None:
            background = sample_corner_background(image)
        return bbox_from_color(image, background, tolerance, alpha_threshold)

    if has_transparency(image):
        return bbox_from_alpha(image, alpha_threshold)

    bg = background if background is not None else sample_corner_background(image)
    return bbox_from_color(image, bg, tolerance, alpha_threshold)


def expand_bbox_preserve_aspect(
    bbox: tuple[int, int, int, int],
    img_w: int,
    img_h: int,
    padding: int,
) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img_w, right + padding)
    bottom = min(img_h, bottom + padding)

    content_w = right - left
    content_h = bottom - top
    if content_w <= 0 or content_h <= 0:
        return 0, 0, img_w, img_h

    target_aspect = img_w / img_h
    content_aspect = content_w / content_h

    if content_aspect >= target_aspect:
        crop_w = content_w
        crop_h = max(content_h, int(round(crop_w / target_aspect)))
        crop_w = int(round(crop_h * target_aspect))
    else:
        crop_h = content_h
        crop_w = max(content_w, int(round(crop_h * target_aspect)))
        crop_h = int(round(crop_w / target_aspect))

    crop_w = min(crop_w, img_w)
    crop_h = min(crop_h, img_h)

    cx = (left + right) / 2
    cy = (top + bottom) / 2
    crop_left = int(round(cx - crop_w / 2))
    crop_top = int(round(cy - crop_h / 2))
    crop_right = crop_left + crop_w
    crop_bottom = crop_top + crop_h

    if crop_left < 0:
        crop_right -= crop_left
        crop_left = 0
    if crop_top < 0:
        crop_bottom -= crop_top
        crop_top = 0
    if crop_right > img_w:
        shift = crop_right - img_w
        crop_left = max(0, crop_left - shift)
        crop_right = img_w
    if crop_bottom > img_h:
        shift = crop_bottom - img_h
        crop_top = max(0, crop_top - shift)
        crop_bottom = img_h

    if crop_right - crop_left <= 0 or crop_bottom - crop_top <= 0:
        return 0, 0, img_w, img_h
    return crop_left, crop_top, crop_right, crop_bottom


def apply_padding(
    bbox: tuple[int, int, int, int],
    img_w: int,
    img_h: int,
    padding: int,
) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    return (
        max(0, left - padding),
        max(0, top - padding),
        min(img_w, right + padding),
        min(img_h, bottom + padding),
    )


def trim_image(
    image: Image.Image,
    *,
    mode: str,
    preserve_aspect: bool,
    alpha_threshold: int,
    background: tuple[int, int, int] | None,
    tolerance: int,
    padding: int,
) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    img_w, img_h = image.size
    bbox = detect_content_bbox(
        image,
        mode=mode,
        alpha_threshold=alpha_threshold,
        background=background,
        tolerance=tolerance,
    )
    if bbox is None:
        return image, None

    if bbox == (0, 0, img_w, img_h):
        return image, bbox

    if preserve_aspect:
        crop_box = expand_bbox_preserve_aspect(bbox, img_w, img_h, padding)
    else:
        crop_box = apply_padding(bbox, img_w, img_h, padding)

    if crop_box == (0, 0, img_w, img_h):
        return image, crop_box

    return image.crop(crop_box), crop_box


def save_trimmed(image: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    suffix = dest.suffix.lower()
    if suffix == ".png":
        out = image
        if out.mode not in {"RGBA", "RGB", "P", "L"}:
            out = out.convert("RGBA")
        out.save(dest, format="PNG")
        return
    if suffix in {".jpg", ".jpeg"}:
        out = image.convert("RGB") if image.mode in {"RGBA", "LA", "P"} else image
        out.save(dest, format="JPEG")
        return
    image.save(dest)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Trim invalid borders from a single image (transparent or solid-color padding)."
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
            "Output image file or directory. "
            f"Default: {format_default_output_help(DEFAULT_OUTPUT_SUBDIR)}"
        ),
    )
    parser.add_argument(
        "--mode",
        choices=("auto", "alpha", "color"),
        default=DEFAULT_MODE,
        help="auto: alpha when present else corner color (default); alpha: transparency only; color: solid background",
    )
    parser.add_argument(
        "--color",
        help="Background color as RRGGBB hex for color/auto fallback (default: corner sample)",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        default=DEFAULT_TOLERANCE,
        help=f"Color match tolerance 0-255 (default: {DEFAULT_TOLERANCE})",
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=DEFAULT_ALPHA_THRESHOLD,
        help=f"Alpha above this value counts as content (default: {DEFAULT_ALPHA_THRESHOLD})",
    )
    parser.add_argument(
        "--padding",
        type=int,
        default=DEFAULT_PADDING,
        help=f"Extra pixels to keep around detected content (default: {DEFAULT_PADDING})",
    )
    parser.add_argument(
        "--tight",
        action="store_true",
        help="Tight crop to content bbox (do not preserve source aspect ratio)",
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

    resolve_tool_bin(repo_root, "image-trim")

    background: tuple[int, int, int] | None = None
    if args.color:
        try:
            background = parse_color(args.color)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1

    image_path = resolve_image_file(args.image)
    if image_path is None:
        return 1

    out_path = resolve_output_path(
        args.output,
        image_path,
        DEFAULT_OUTPUT_SUBDIR,
        output_filename(image_path),
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

    preserve_aspect = not args.tight
    print(f"Image:        {image_path}")
    print(f"Mode:         {args.mode}")
    print(f"Aspect ratio: {'preserve source' if preserve_aspect else 'tight bbox'}")
    print(f"Padding:      {args.padding}px")
    print(f"Output:       {out_path}")
    print()

    with Image.open(image_path) as img:
        if img.format == "JPEG" and image_path.suffix.lower() == ".png":
            print(
                f"Warning: {image_path.name} is JPEG data with a .png extension — "
                "transparency was already lost before trim. Use the original RGBA PNG.",
                file=sys.stderr,
            )

        prepared = prepare_image(img)
        original_size = prepared.size
        result, crop_box = trim_image(
            prepared,
            mode=args.mode,
            preserve_aspect=preserve_aspect,
            alpha_threshold=args.alpha_threshold,
            background=background,
            tolerance=args.tolerance,
            padding=args.padding,
        )

    if crop_box is None or result.size == original_size:
        print(f"No trim needed: {image_path} ({original_size[0]}x{original_size[1]})")
        return 0

    print(
        f"[run]  {image_path.name} "
        f"({original_size[0]}x{original_size[1]} -> {result.size[0]}x{result.size[1]})"
    )
    save_trimmed(result, out_path)
    print()
    print(f"Done. wrote {out_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
