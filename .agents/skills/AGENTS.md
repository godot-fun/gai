# Skill Dependency Manager

## Skill layout

Keep **docs** and **code** separate. Skill instructions (`SKILL.md`) stay with the skill definition; executable scripts live at the repo root under `.ai/`, named after the skill.

| What | Where |
|------|-------|
| Skill instructions (`SKILL.md`, references) | The skill's own folder (next to `SKILL.md`) |
| Skill scripts (Python / shell / etc.) | `.ai/<skill-name>/` |
| Script tests (`test_<script>.py`) | `.ai/<skill-name>/` — default `python` skills only |
| CLI manual (`<skill-name>.md`) | `cli/` — copy-paste unit-test and manual CLI commands |
| Toolchains (Python, FFmpeg, venvs) | `.dependency/` |

```
project-root/
├── cli/
│   ├── audio-to-wav.md           # unit tests + manual CLI
│   └── ai-text-to-speech.md
├── .ai/
│   ├── audio-to-wav/
│   │   ├── convert.py
│   │   └── test_convert.py
│   └── ai-text-to-speech/
│       └── tts.py
└── .dependency/
```

- The folder name under `.ai/` **must match** the skill name.
- Put scripts **directly** under `.ai/<skill-name>/` — do not add an extra `scripts/` directory.
- **Default `python` skills:** include a test file named after the script (`convert.py` → `test_convert.py`). If a directory has several scripts, give each one a matching `test_<script>.py`.
- **Every skill with scripts** gets `cli/<skill-name>.md` — unit-test commands (when present) and manual CLI examples using the correct manifest `bin`. Write each command as **one line** (no `\` line breaks) so it pastes into the console as a single command.
- **Non-default runtime** (a tool venv or `python-3.11`, etc.): do **not** add `test_*.py`. Put CLI commands in `cli/<skill-name>.md` only.
- Do **not** put executable scripts next to `SKILL.md`.
- SKILL.md commands must point at `.ai/<skill-name>/...`.
- Every skill script must start with a module docstring that includes **Usage**: full commands from the repo root, using the manifest interpreter. Write each command as **one line** (no `\` line breaks). Never use host `python`.
- If the skill uses the **default** `python` entry, say so in the docstring.
- If the skill does **not** use default Python, the docstring **must** say that explicitly: which manifest entry, which version (e.g. Python 3.11), and that default `python` must not be used.

Default `python`:

```
"""
Short description.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/<skill-name>/<script>.py input [flags]
"""
```

Non-default runtime (must state version + entry):

```
"""
Short description.

Not default python. Run through the <entry> manifest bin
(Python 3.11 venv at .dependency/<entry>/.venv/).
Never use default python or host python/py.

Usage
-----
    .dependency/<entry>/.venv/Scripts/python.exe .ai/<skill-name>/<script>.py input [flags]
"""
```

## Python style (`.ai/` skill scripts)

- **One-line imports.** Each `import` or `from … import` must stay on a **single line** — do not wrap imports in parentheses across multiple lines.

## Run skill scripts

When a skill has scripts, run them from the project root as the skill docs say. Do not use your own commands unless the skill says the script is for reference only. Canonical script path: `.ai/<skill-name>/`.

Run tests the same way — same interpreter from `.dependency/manifest.json`, from the repo root:

```bash
.dependency/python/python.exe .ai/audio-to-wav/test_convert.py
```

If a skill uses a **non-default** runtime, skip `test_*.py`. Use the CLI in `cli/<skill-name>.md` (that runtime's `bin`).

Manual CLI examples for any skill live in `cli/<skill-name>.md`, not under `.ai/`.

Do not use host `python` / `pytest` to run skill tests.

### No bypass

Even when a skill script wraps FFmpeg or another CLI, call it through the skill script — do not hand-write equivalent commands.

### Workflow

1. Find the script and command in the skill docs.
2. Run it. If something is missing, install it (see **Dependencies** below or skill setup steps), then run the same command again.
3. If it fails, fix the setup or inputs and try again. Ask before using a different approach.

After installing anything, say what you installed and which command you ran.

## Skill pipelines

When the user lists **multiple skills in sequence**, chain them: **each step's output is the next step's input**. Never point a later step back at the original source.

Each skill writes beside its input into `<input-dir>/<skill-name>/`, so chained runs nest:

```
source/file.ext
  → source/skill-a/out.ext
  → source/skill-a/skill-b/out.ext
  → source/skill-a/skill-b/skill-c/out.ext   ← final
```

1. **Order** — user's list, left to right (or top to bottom).
2. **Input** — step 1 uses the source file; later steps pass the **prior output** using that skill's input flag from `SKILL.md` (`--image`, `--audio`, `--video`, etc.).
3. **One file per run** — one input per invocation; repeat the full pipeline for each file when batching a folder.
4. **No bypass** — run every step through its bundled script; do not merge steps into one hand-written command.
5. **Sources untouched** — report the deepest nested path as the final result.

The pipeline only wires **which file** each step receives.

## Dependencies

External CLIs, language runtimes, and skill-only toolchains install into `.dependency/`. Do not put **project/business** packages here (Godot addons, game server deps, app `requirements.txt`, etc.).

| Kind | Name examples | Install location |
|------|---------------|------------------|
| Language runtime | `python`, `python-3.11`, `node-20`, `rust-1.75`, `go-1.22` | `.dependency/<name>/` |
| CLI tool (standalone binary) | `ffmpeg`, `llama-cpp-cpu`, `llama-cpp-gpu`, `git`, `jq`, `curl`, `imagemagick` | `.dependency/<name>/` or `.dependency/<name>-tool/` |
| Python third-party tool | `rembg`, cloned GitHub projects | `.dependency/<name>/.venv/` |

**Root:** `.dependency/`  
**Manifest:** `.dependency/manifest.json`

Each manifest name maps to a dedicated directory under `.dependency/`. After populating, set `populated: true` and correct `bin` paths in the manifest.

`populated: false` in `.dependency/manifest.json` is not a reason to skip a skill script. Install the missing tool here first, then run the same skill command again.

### Language runtimes — `.dependency/` only

**Never** use a language runtime from outside `.dependency/`.

This applies to every runtime in the table above (`python`, `python-3.11`, `node-20`, `rust-1.75`, `go-1.22`, etc.).

**Forbidden** — do not invoke, discover, or fall back to any of these:

- Commands on the host PATH or version managers — e.g. `python`, `py`, `python3`, `node`, `npm`, `cargo`, `go`, `pyenv`, `nvm`, `rustup`
- **Any absolute path** to an interpreter outside `.dependency/` — e.g. `C:\Python314\python.exe`, `/usr/bin/python3`, `~/miniconda3/python`
- **Host virtual environments** anywhere on disk — `.venv/`, `venv/`, `env/` under the user profile, other repos, Desktop, Downloads, `AppData`, `Program Files`, `~/.local`, etc.
- **Conda / Miniconda / Anaconda** base or named envs
- **IDE- or editor-bundled** runtimes (VS Code, PyCharm, etc.)
- **Other projects'** Python/Node installs, even if they already have the package you need

The **only** allowed interpreter paths are `bin` values in `.dependency/manifest.json` (which must live under `.dependency/`). For Python third-party tools, that includes venvs at `.dependency/<tool-name>/.venv/` only.

- Resolve the runtime from `manifest.json` → `<entry>.bin`.
- If `populated: false`, install that runtime under `.dependency/` first — do **not** fall back to any host install.
- Skill docs may show shorthand (`python`, `py`, `node`); always substitute the manifest `bin` path when running commands.
- If a command fails, fix the `.dependency/` install — never retry with a different host Python or venv.

### Python default version

When a skill does **not** specify a Python version, assume **Python 3.14** as the default runtime.

- Install to `.dependency/python/` and register as the `python` entry in `manifest.json`.
- Skills that only reference `python` (no version suffix) rely on this default.
- If a skill explicitly requires another version (e.g. `python-3.11`), use a separate manifest entry and install directory instead.
- Install runtimes by extracting portable archives into `.dependency/<name>/`; never run interactive/system installers or modify the host environment.

The `python` runtime is for **stdlib-only** skill scripts (e.g. audio wrappers, path/batch wrappers). Do **not** `pip install` into `.dependency/python/` itself.

### Node.js default version

When a skill does **not** specify a Node.js version, assume **Node.js v24.22.0** as the default runtime.

- Install to `.dependency/node/` and register as the `node` entry in `manifest.json`.
- Skills that only reference `node` (no version suffix) rely on this default.
- If a skill explicitly requires another version (e.g. `node-22`), use a separate manifest entry and install directory instead.
- Install runtimes by extracting portable archives into `.dependency/<name>/`; never run interactive/system installers or modify the host environment.

### Standalone CLI tools

When a skill depends on a portable upstream binary (e.g. FFmpeg), follow this order:

When one CLI has separate CPU and GPU builds, register each build as its own dependency. Use matching directory and manifest names such as `.dependency/llama-cpp-cpu/` → `llama-cpp-cpu` and `.dependency/llama-cpp-gpu/` → `llama-cpp-gpu`. Do not place both builds under a model-specific directory or combine them into custom fields such as `gpu_bin`. Keep reusable runtimes separate from model weights; for example, store MiniCPM weights under `.dependency/minicpm-v-4.6/model/` while both llama.cpp builds remain independently reusable.

```json
"llama-cpp-cpu": {
  "populated": true,
  "bin": ".dependency/llama-cpp-cpu/llama-mtmd-cli.exe"
},
"llama-cpp-gpu": {
  "populated": true,
  "bin": ".dependency/llama-cpp-gpu/llama-mtmd-cli.exe"
},
"minicpm-v-4.6": {
  "populated": true,
  "model": ".dependency/minicpm-v-4.6/model"
}
```

1. **Create the install directory** under `.dependency/` — use the manifest key name (e.g. `.dependency/ffmpeg/`).

2. **Download the release asset** from the upstream project (GitHub Releases, vendor site). Extract so `bin` in `manifest.json` points at the executable.

   ```bash
   # FFmpeg (Windows)
   # Download ffmpeg-release-essentials.zip → extract to .dependency/ffmpeg/
   # Result: .dependency/ffmpeg/bin/ffmpeg.exe
   ```

   On Unix, use the platform binary without `.exe` (e.g. `.dependency/ffmpeg/bin/ffmpeg`).

3. **Register** in `manifest.json` with `bin` pointing at the executable:

   ```json
   "ffmpeg": {
     "populated": true,
     "bin": ".dependency/ffmpeg/bin/ffmpeg.exe"
   }
   ```

4. **Run** through the skill script when one exists — do not hand-write equivalent CLI unless the skill says the script is reference-only:

   ```bash
   .dependency/python/python.exe .ai/audio-to-wav/convert.py --audio audio/input.flac
   ```

   Some skills wrap the binary with a stdlib Python script (`python` manifest entry); others invoke the CLI binary directly via its own manifest entry (`ffmpeg`).

### Python third-party tools (`.venv`)

When a skill depends on a Python package or a GitHub project with pip dependencies (e.g. rembg), follow this order:

1. **Clone the upstream project** into `.dependency/<tool-name>/`:

   ```bash
   git clone https://github.com/example/rembg .dependency/rembg
   ```

   The clone root is `.dependency/<tool-name>/`; `.venv` is created as a sibling inside that directory.

2. **Determine the required Python version** from the cloned project — check `pyproject.toml`, `.python-version`, `setup.py`, `setup.cfg`, `requirements.txt`, or `README`. If the project does not pin a version, fall back to the skill docs; if still unspecified, use the default `python` entry (**3.14**).

3. **Ensure that Python runtime exists** — look up the matching entry in `manifest.json` (e.g. `python` or `python-3.11`). If missing or `populated: false`, install it under `.dependency/` first (see **Python default version**). Use only that entry's `bin` (see **Language runtimes — `.dependency/` only**).

4. **Create `.venv`** at `.dependency/<tool-name>/.venv/` with that runtime:

   ```bash
   # default — Python 3.14
   .dependency/python/python -m venv .dependency/rembg/.venv

   # project requires Python 3.11
   .dependency/python-3.11/python -m venv .dependency/rembg/.venv
   ```

5. **Install dependencies** only inside that venv — never into system Python or the bare runtime:

   ```bash
   # from cloned repo
   .dependency/rembg/.venv/Scripts/python.exe -m pip install .
   .dependency/rembg/.venv/Scripts/python.exe -m pip install -r requirements.txt

   # extra packages named by the skill
   .dependency/rembg/.venv/Scripts/python.exe -m pip install "rembg[cpu]"
   ```

   On Unix, use `.dependency/rembg/.venv/bin/python` instead of `Scripts/python.exe`.

6. **Register** in `manifest.json` with `bin` pointing at the venv's Python interpreter. On Windows use `Scripts/python.exe`, on Unix use `bin/python`.

7. **Run** skill scripts and tool CLIs through the venv interpreter:

   ```bash
   .dependency/rembg/.venv/Scripts/python.exe .ai/image-remove-background/remove_background.py ...
   ```

   Prefer the venv's `python -m <module>` when a console script is missing.

### manifest.json

Top-level keys match install directory names. Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `populated` | boolean | Whether the install directory contains a valid upstream toolchain |
| `bin` | string | Executable path, relative to repo root |

Example:

```json
{
  "python": {
    "populated": false,
    "bin": ".dependency/python/python"
  },
  "ffmpeg": {
    "populated": true,
    "bin": ".dependency/ffmpeg/bin/ffmpeg"
  },
  "rembg": {
    "populated": true,
    "bin": ".dependency/rembg/.venv/Scripts/python.exe"
  }
}
```
