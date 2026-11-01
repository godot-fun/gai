---
name: file-naming-normalization
description: Normalizes asset filenames by splitting on common separators, stripping asset IDs and optional user strings from each segment, then joining with underscores (snake_case). Use when normalizing asset filenames, batch-renaming SFX/UI textures, file naming normalization, asset naming convention, slug normalization, or snake_case asset names.
---

# File Naming Normalization

Normalize asset filenames: split → clean each segment → join with `_` (snake_case).

## Rules

When this skill applies, read and follow [dependency-manager](../dependency-manager.md) — run scripts as documented, install missing tools into `.dependency/`.

## Quick Start

Default: split on `_`, `-`, `.`, and spaces; strip leading/trailing digits from each segment; join with `_`:

```bash
.dependency/python/python .ai/file-naming-normalization/normalize.py path/to/file_or_folder
```

Preview without renaming:

```bash
.dependency/python/python .ai/file-naming-normalization/normalize.py Audio/SFX --dry-run
```

## Workflow

1. **Split** the filename stem (extension is preserved) on common separators: `_`, `-`, `.`, whitespace.
2. **Clean** each segment:
   - Drop pure-digit segments with 4+ digits (asset IDs like `38126`)
   - Keep short pure-digit segments as variant indices (`1`, `2`, `01`)
   - Remove leading digits from mixed segments (`001Hero` → `Hero`)
   - Remove trailing digits from mixed segments (`Attack02` → `Attack`, `foisal72` → `foisal`)
   - Remove user-given strings (see `--strip`)
3. **Drop** empty segments after cleaning.
4. **Join** remaining segments with `_`.
5. **Rename** in place (or write to `--output-dir`).

## Examples

| Input | Output |
|-------|--------|
| `001_Hero_Attack_02.wav` | `001_Hero_Attack_02.wav` (already snake_case) |
| `001-Hero-Attack-02.wav` | `001_Hero_Attack_02.wav` |
| `sfx-button-click.mp3` | `sfx_button_click.mp3` |
| `UI 12 Panel Open.png` | `UI_12_Panel_Open.png` |
| `freesound_community-shoot-1-81135.wav` | `freesound_community_shoot_1.wav` |
| `SFX_001_button.wav` with `--strip SFX` | `001_button.wav` |

```bash
# Strip custom strings (repeatable)
.dependency/python/python .ai/file-naming-normalization/normalize.py Assets --strip SFX --strip UI

# Recursive folder
.dependency/python/python .ai/file-naming-normalization/normalize.py Assets -r

# Copy normalized files to another folder (originals unchanged)
.dependency/python/python .ai/file-naming-normalization/normalize.py Assets -o normalized/ -r
```

## Output

`--dry-run` preview (unchanged files such as `001_Hero_Attack_02.wav` are omitted):

```
Assets/001-Hero-Attack-02.wav -> Assets/001_Hero_Attack_02.wav
Assets/freesound_community-shoot-1-81135.wav -> Assets/freesound_community_shoot_1.wav
Assets/sfx-button-click.mp3 -> Assets/sfx_button_click.mp3
Assets/UI 12 Panel Open.png -> Assets/UI_12_Panel_Open.png

Dry run: 4 file(s) would be renamed.
```

In-place rename:

```
Assets/001-Hero-Attack-02.wav -> Assets/001_Hero_Attack_02.wav

Renamed 1 file(s).
```

Nothing to change:

```
All filenames already normalized.
```

With `--strip SFX`:

```
Assets/SFX_001_button.wav -> Assets/001_button.wav

Renamed 1 file(s).
```

Copy to `--output-dir` (originals kept):

```
Assets/SFX_001_button.wav -> normalized/001_button.wav

Renamed 1 file(s).
```

Name collision (exit code 1):

```
Name collision: 'Assets/Hero-Attack.wav' and 'Assets/Hero.Attack.wav' both map to 'Assets/Hero_Attack.wav'
```

## Common Flags

`-r` / `--recursive` · `--strip TEXT` (repeatable) · `--strip-case-insensitive` · `-o` / `--output-dir` · `--dry-run` · `--overwrite`

## Agent Notes

1. Use the bundled script; do not hand-write rename loops unless the script cannot cover the case.
2. Always run `--dry-run` first when normalizing many files; show the user the preview.
3. `--strip` removes the given substring anywhere inside each segment (not only at edges). Pass one `--strip` per string.
4. Segments that become empty after cleaning are dropped (`81135` alone → skipped).
5. Collisions (two files mapping to the same name) abort with an error — resolve manually or normalize in smaller batches.
6. Only renames files; does not rename directories.

## CLI

Copy-paste commands: [cli/file-naming-normalization.md](../../../cli/file-naming-normalization.md)
