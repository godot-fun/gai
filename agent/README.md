# Install Godot

Instructions for agents setting up this repository. Use the same `.dependency/` layout and `manifest.json` rules as in `.agents/skills/dependency-manager.md`. Do not add an install script — read the project config, download the matching engine, register the manifest, and verify.

## Resolve the engine version

1. Read the repository root `project.godot` as text.
2. Under `[application]`, parse `config/features` (a `PackedStringArray`).
3. The **engine feature version** is the first array element that looks like `MAJOR.MINOR` (digits and one dot, e.g. `4.6`). Ignore entries such as `GL Compatibility`.
4. Download **Godot stable** for that line: choose the **latest stable patch release** whose version starts with that `MAJOR.MINOR` (same minor as the feature tag, not a newer minor).

## Install under `.dependency/`

1. Create `.dependency/godot/`.
2. Download the official Godot Engine **stable** portable archive for the current OS from the engine’s GitHub releases (extract only — no OS installer).
3. Extract the engine into `.dependency/godot/`. On Windows, the manifest `bin` is the main **`Godot_v*_win64.exe`** (the one you double-click to run the editor); you may keep the **`_console`** sibling in the same folder for manual terminal use, but do not point `bin` at it. On Linux, use the extracted `linux.x86_64` binary. On macOS, extract `Godot.app` and set `bin` to `Godot.app/Contents/MacOS/Godot`.

## Register `manifest.json`

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

## Verify

From the repository root, run the manifest `bin` with `--headless --path . --quit` (or open the root `project.godot` in the editor by launching the same `bin` without headless flags).

For tests, CI, automation, and the editor, always invoke Godot through the manifest `bin` — not a copy on `PATH` or outside `.dependency/`.
