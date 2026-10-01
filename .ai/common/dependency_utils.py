"""Shared repository and dependency resolution helpers for skill scripts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def find_repo_root(start: Path) -> Path | None:
    """Find the nearest repository containing the dependency manifest."""
    resolved_start = start.resolve()
    for parent in [resolved_start, *resolved_start.parents]:
        if (parent / ".dependency" / "manifest.json").is_file():
            return parent
    return None


def resolve_executable(path: Path) -> Path:
    """Resolve an executable path, including Windows .exe suffix fallback."""
    if path.is_file():
        return path
    if sys.platform == "win32" and path.suffix.lower() != ".exe":
        candidate = path.with_name(f"{path.name}.exe")
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(path)


def resolve_tool_entry(repo_root: Path, tool_name: str) -> dict[str, Any]:
    """Read and validate one tool entry from the dependency manifest."""
    manifest_path = repo_root / ".dependency" / "manifest.json"
    entry = json.loads(manifest_path.read_text(encoding="utf-8")).get(tool_name)
    if not entry:
        print(
            f"Tool '{tool_name}' not found in .dependency/manifest.json. "
            "See skill-dependency-manager and the skill's SKILL.md.",
            file=sys.stderr,
        )
        sys.exit(1)
    if not entry.get("populated", False):
        print(
            f"Tool '{tool_name}' is not populated. "
            f"Install it under {repo_root / '.dependency' / tool_name} and set populated: true "
            "in .dependency/manifest.json.",
            file=sys.stderr,
        )
        sys.exit(1)
    return entry


def resolve_tool_bin(repo_root: Path, tool_name: str) -> Path:
    """Resolve a populated manifest tool entry to an existing executable."""
    entry = resolve_tool_entry(repo_root, tool_name)
    bin_path = entry["bin"]
    if isinstance(bin_path, list):
        bin_path = bin_path[0]
    try:
        return resolve_executable(repo_root / bin_path)
    except FileNotFoundError:
        print(
            f"Executable for '{tool_name}' not found at {repo_root / bin_path}. "
            "Check .dependency/manifest.json bin path.",
            file=sys.stderr,
        )
        sys.exit(1)


def resolve_tool_model_dir(repo_root: Path, tool_name: str) -> Path:
    """Resolve a populated manifest tool entry's existing model directory."""
    entry = resolve_tool_entry(repo_root, tool_name)
    model_path = repo_root / entry["model"]
    if not model_path.is_dir():
        print(f"Model directory for '{tool_name}' not found at {model_path}.", file=sys.stderr)
        sys.exit(1)
    return model_path
