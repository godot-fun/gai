"""
Remove solid-color backgrounds (white, green, magenta) via color key + flood fill.

Not default python. Run through the image-remove-white-background manifest bin
(Python venv at .dependency/image-remove-white-background/.venv/).
Never use default python or host python/py.

Usage
-----
    .dependency/image-remove-white-background/.venv/Scripts/python.exe .ai/image-remove-white-background/remove_white_bg.py --image image/foo.png
    .dependency/image-remove-white-background/.venv/Scripts/python.exe .ai/image-remove-white-background/remove_white_bg.py --image image/foo.png --preset green --tolerance 30
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.image_utils import image_output_name, resolve_image_file  # noqa: E402
from common.output_utils import configure_utf8_stdio, format_default_output_help, resolve_output_path  # noqa: E402

DEFAULT_OUTPUT_SUBDIR = "image-remove-white-background"
DEFAULT_PRESET = "white"
DEFAULT_TOLERANCE = 25
DEFAULT_FEATHER = 2
DEFAULT_MODE = "global"

PRESETS: dict[str, tuple[int, int, int]] = {
    "white": (255, 255, 255),
    "green": (0, 255, 0),
    "magenta": (255, 0, 255),
}

PRESET_DEFAULT_TOLERANCE: dict[str, int] = {
    "white": 25,
    "green": 40,
    "magenta": 40,
}


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


def is_key_pixel(
    r: int,
    g: int,
    b: int,
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
) -> bool:
    if white_mode:
        floor = 255 - tolerance
        return r >= floor and g >= floor and b >= floor
    kr, kg, kb = key
    return max(abs(r - kr), abs(g - kg), abs(b - kb)) <= tolerance


def build_flood_mask(
    pixels: list[tuple[int, ...]],
    width: int,
    height: int,
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
    seeds: list[tuple[int, int]],
) -> bytearray:
    def matches(idx: int) -> bool:
        r, g, b = pixels[idx][:3]
        return is_key_pixel(r, g, b, key, tolerance, white_mode=white_mode)

    remove = bytearray(width * height)
    visited = bytearray(width * height)
    queue: deque[int] = deque()

    for x, y in seeds:
        if not 0 <= x < width or not 0 <= y < height:
            continue
        idx = y * width + x
        if not visited[idx] and matches(idx):
            visited[idx] = 1
            queue.append(idx)

    while queue:
        idx = queue.popleft()
        remove[idx] = 1
        x = idx % width
        y = idx // width
        if x > 0:
            nidx = idx - 1
            if not visited[nidx] and matches(nidx):
                visited[nidx] = 1
                queue.append(nidx)
        if x + 1 < width:
            nidx = idx + 1
            if not visited[nidx] and matches(nidx):
                visited[nidx] = 1
                queue.append(nidx)
        if y > 0:
            nidx = idx - width
            if not visited[nidx] and matches(nidx):
                visited[nidx] = 1
                queue.append(nidx)
        if y + 1 < height:
            nidx = idx + width
            if not visited[nidx] and matches(nidx):
                visited[nidx] = 1
                queue.append(nidx)

    return remove


def border_seeds(width: int, height: int) -> list[tuple[int, int]]:
    seeds: list[tuple[int, int]] = []
    for x in range(width):
        seeds.append((x, 0))
        seeds.append((x, height - 1))
    for y in range(1, height - 1):
        seeds.append((0, y))
        seeds.append((width - 1, y))
    return seeds


def center_seeds(width: int, height: int) -> list[tuple[int, int]]:
    return [(width // 2, height // 2)]


def build_border_mask(
    pixels: list[tuple[int, ...]],
    width: int,
    height: int,
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
) -> bytearray:
    return build_flood_mask(
        pixels,
        width,
        height,
        key,
        tolerance,
        white_mode=white_mode,
        seeds=border_seeds(width, height),
    )


def build_center_mask(
    pixels: list[tuple[int, ...]],
    width: int,
    height: int,
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
) -> bytearray:
    return build_flood_mask(
        pixels,
        width,
        height,
        key,
        tolerance,
        white_mode=white_mode,
        seeds=center_seeds(width, height),
    )


def build_both_mask(
    pixels: list[tuple[int, ...]],
    width: int,
    height: int,
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
) -> bytearray:
    border = build_border_mask(
        pixels, width, height, key, tolerance, white_mode=white_mode
    )
    center = build_center_mask(
        pixels, width, height, key, tolerance, white_mode=white_mode
    )
    return bytearray(1 if border[i] or center[i] else 0 for i in range(len(border)))


def build_global_mask(
    pixels: list[tuple[int, ...]],
    key: tuple[int, int, int],
    tolerance: int,
    *,
    white_mode: bool,
) -> bytearray:
    remove = bytearray(len(pixels))
    for idx, pixel in enumerate(pixels):
        r, g, b = pixel[:3]
        if is_key_pixel(r, g, b, key, tolerance, white_mode=white_mode):
            remove[idx] = 1
    return remove


def apply_feather(alpha: list[int], width: int, height: int, radius: int) -> None:
    if radius <= 0:
        return

    from PIL import ImageFilter

    alpha_img = Image.new("L", (width, height))
    alpha_img.putdata(alpha)
    blurred = alpha_img.filter(ImageFilter.GaussianBlur(radius=radius))
    alpha[:] = list(blurred.getdata())


def crop_transparent(image: Image.Image) -> Image.Image:
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    bbox = image.split()[3].getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def remove_solid_background(
    source: Path,
    *,
    key: tuple[int, int, int],
    tolerance: int,
    feather: int,
    mode: str,
    crop: bool,
) -> Image.Image:
    with Image.open(source) as img:
        rgb = img.convert("RGB")
        width, height = rgb.size
        pixels = list(rgb.getdata())
        white_mode = key == (255, 255, 255)

        if mode == "border":
            remove = build_border_mask(
                pixels, width, height, key, tolerance, white_mode=white_mode
            )
        elif mode == "center":
            remove = build_center_mask(
                pixels, width, height, key, tolerance, white_mode=white_mode
            )
        elif mode == "both":
            remove = build_both_mask(
                pixels, width, height, key, tolerance, white_mode=white_mode
            )
        else:
            remove = build_global_mask(pixels, key, tolerance, white_mode=white_mode)

        alpha = [0 if remove[idx] else 255 for idx in range(len(pixels))]
        if feather > 0:
            apply_feather(alpha, width, height, feather)

        alpha_img = Image.new("L", (width, height))
        alpha_img.putdata(alpha)
        result = rgb.convert("RGBA")
        result.putalpha(alpha_img)

        if crop:
            result = crop_transparent(result)
        return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove solid-color backgrounds (white/green/magenta) from a single image."
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
        "--preset",
        choices=sorted(PRESETS),
        default=DEFAULT_PRESET,
        help=f"Background color preset (default: {DEFAULT_PRESET})",
    )
    parser.add_argument(
        "--color",
        help="Custom key color as RRGGBB hex (overrides --preset)",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        help="Color match tolerance 0-255 (default depends on preset)",
    )
    parser.add_argument(
        "--feather",
        type=int,
        default=DEFAULT_FEATHER,
        help=f"Gaussian blur radius on alpha edges (default: {DEFAULT_FEATHER}, 0=off)",
    )
    parser.add_argument(
        "--mode",
        choices=("border", "center", "both", "global"),
        default=DEFAULT_MODE,
        help=(
            "global: remove all matching pixels (default); both: union of border and center; "
            "border: flood-fill from edges; center: flood-fill from image center"
        ),
    )
    parser.add_argument(
        "--crop",
        action="store_true",
        help="Crop transparent borders after keying",
    )
    return parser.parse_args()


def main() -> int:
    configure_utf8_stdio()
    args = parse_args()

    repo_root = find_repo_root(Path(__file__))
    if repo_root is None:
        print(
            "Could not find .dependency/manifest.json. "
            "Run from a repo that follows dependency-manager.",
            file=sys.stderr,
        )
        return 1

    resolve_tool_bin(repo_root, "image-remove-white-background")

    image_path = resolve_image_file(args.image)
    if image_path is None:
        return 1

    if args.color:
        try:
            key = parse_color(args.color)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        preset = "custom"
    else:
        preset = args.preset
        key = PRESETS[preset]

    tolerance = (
        args.tolerance
        if args.tolerance is not None
        else PRESET_DEFAULT_TOLERANCE.get(preset, DEFAULT_TOLERANCE)
    )
    if not 0 <= tolerance <= 255:
        print("--tolerance must be between 0 and 255", file=sys.stderr)
        return 1
    if args.feather < 0:
        print("--feather must be >= 0", file=sys.stderr)
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
    print(f"Preset: {preset} key={key} tolerance={tolerance} mode={args.mode} feather={args.feather}")
    print(f"Output: {out_path}")
    print()

    out_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        print(f"[run]  {image_path.name} -> {out_path.name}")
        result = remove_solid_background(
            image_path,
            key=key,
            tolerance=tolerance,
            feather=args.feather,
            mode=args.mode,
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
