# Dependency

Instructions for agents setting up this repository. Runtimes and tools live under `.dependency/` and are registered in `.dependency/manifest.json` — follow the same rules as in `.agents/skills/dependency-manager.md`. Do not add an install script: read project config or the relevant skill doc, download the matching toolchain, register the manifest, and verify.

Install additional tools when a skill needs them; each skill's `SKILL.md` describes its own entries. **Godot is required** for the editor, tests, and the desktop agent.

## Godot

### Resolve the engine version

1. Read the repository root `project.godot` as text.
2. Under `[application]`, parse `config/features` (a `PackedStringArray`).
3. The **engine feature version** is the first array element that looks like `MAJOR.MINOR` (digits and one dot, e.g. `4.6`). Ignore entries such as `GL Compatibility`.
4. Download **Godot stable** for that line: choose the **latest stable patch release** whose version starts with that `MAJOR.MINOR` (same minor as the feature tag, not a newer minor).

### Install under `.dependency/`

1. Create `.dependency/godot/`.
2. Download the official Godot Engine **stable** portable archive for the current OS from the engine’s GitHub releases (extract only — no OS installer).
3. Extract the engine into `.dependency/godot/`. On Windows, use **`Godot_v*_win64.exe`**. On Linux, use the extracted `linux.x86_64` binary. On macOS, extract `Godot.app` and set `bin` to `Godot.app/Contents/MacOS/Godot`.

### Register `manifest.json`

Add or update the `godot` entry in `.dependency/manifest.json`:

- Set `populated` to `true` only after the `bin` file exists on disk; use `false` while installing.
- Set `bin` to the **main editor** executable path, relative to the repo root, using the **actual filename** from the release you extracted (version string must match the build you downloaded, not a hard-coded example). The same binary supports `--headless` for tests and automation.

Example shape — set `bin` to the real editor binary name from the release you installed:

```json
"godot": {
  "populated": true,
  "bin": ".dependency/godot/<extracted-editor-binary>"
}
```

### Verify

From the repository root, using the manifest `bin`:

1. Run `--headless --import --path .` once so the project cache is built.
2. Run a unit test scene, for example `--headless --path . res://test/common/CommonTest.tscn` — exit code must be `0`.

This project has no `run/main_scene`; `--headless --path . --quit` alone may exit non-zero — that is not a failed install.

For tests, CI, automation, and the editor, always invoke Godot through the manifest `bin` — not a copy on `PATH` or outside `.dependency/`.
