# GAI

**An all-in-one AI workspace for Godot game development: build and verify code with a desktop agent, then connect audio, image, and video tools through visual workflows.**

GAI brings together a coding agent, reusable skills, command-line tools, and a lightweight Godot framework in one repository. Ask the agent to inspect a project, edit files, run commands, and execute tests—or connect processing nodes visually to build repeatable asset pipelines.

## Desktop Coding Agent

![GAI desktop coding agent](agent/asset/image/screenshot/gai_1.png)

Complete the full loop from request to verification in a native Godot desktop interface:

- Stream responses, command output, and file changes in real time
- Use built-in `read`, `write`, `edit`, `delete`, `list_dir`, `glob`, `grep`, `bash`, `web_search`, and `web_fetch` tools
- Run a model loop that calls tools, feeds their results back to the model, and repeats until it stops asking for tools or you end the run
- Run multiple independent sessions and switch between them while agents are working
- Preserve conversation history and pin frequently used sessions
- Create workspace checkpoints before changes, with support for reverting conversations and files
- Connect to OpenAI-compatible APIs with configurable models, endpoints, and proxies

## Visual Workflow Editor

![GAI visual workflow editor](agent/asset/image/screenshot/workflow_1.png)

The workflow editor exposes repository skills as connectable nodes. Select an input, connect processing steps, and run the entire pipeline at once:

- Browse skill nodes grouped into Input, Audio, Image, Video, and other categories
- Connect type-safe `audio`, `image`, `video`, `text`, and `folder` ports
- Process entire folders with batch iteration and glob matching
- Execute nodes in dependency order while monitoring progress and logs
- Save workflows as `.workflow.json` files and reopen them later
- Switch between English and Chinese interfaces

The screenshot above shows this audio pipeline:

```text
Input folder
  → Batch for each
  → Convert to WAV
  → Trim leading and trailing silence
  → Normalize loudness
  → Standardize sample rate
  → Export to OGG
```

## Features

| Module | Capabilities |
| --- | --- |
| Agent | Understand codebases, edit files, run commands and tests, and search the web |
| Workflow | Compose skills as nodes with batch processing, persistence, and execution logs |
| AI | Text-to-speech and zero-shot voice cloning |
| Audio | Conversion, trimming, denoising, fades, volume and loudness processing, and sample-rate standardization |
| Image | PNG conversion, local inpainting, sprite-sheet splitting, background removal, trimming, and resizing |
| Video | Audio-track processing, 60 FPS interpolation, 4K upscaling and normalization, merging, compression, and OGV export |
| Storyboard | Bilingual storyboards, HTML animation previews, narration, audio/video mixing, and multi-platform publishing copy |
| Godot Framework | AI chat (streaming, tools, cancellation), HTTP, subprocesses, concurrent executors, networking, async resources, audio, scenes, logging, settings, localization, UI tokens, testing, and shared utilities |
| C++ (godot-cpp) | GDExtension support via godot-cpp for native classes usable from GDScript |

See [`.agents/skills/README.md`](.agents/skills/README.md) for the complete skill catalog and usage details.

## Quick Start

### Run the Coding Agent

1. Open the root `project.godot` file in Godot.
2. Set `OPENAI_API_KEY`, or configure the API connection from the Agent toolbar.
3. Open `agent/Agent.tscn` and press **F6** to run the current scene.

Alternatively, temporarily set the main scene to:

```ini
run/main_scene="res://agent/Agent.tscn"
```

### Run the Workflow Editor

1. Open this project in Godot.
2. Open `agent/app/workflow/Workflow.tscn`.
3. Press **F6**, then double-click nodes in the skill library and connect them on the canvas.
4. Provide the required input paths and click **Run**.

See the [Workflow documentation](agent/app/workflow/README.md) for more details.

## Skills and CLI

Each skill consists of two parts:

- [`.agents/skills/`](.agents/skills/): instructions and execution constraints for AI agents
- [`.ai/`](.ai/): scripts that perform the actual processing

Run all scripts from the repository root. Source files are not overwritten by default. Refer to the corresponding `SKILL.md` for commands, flags, dependencies, and output rules.

For example, to convert an audio file to WAV:

```bash
.dependency/python/python .ai/audio-to-wav/convert.py --audio path/to/audio.mp3
```

Skills can be invoked by the desktop agent, executed directly from the command line, or combined into reusable visual workflows.

## Agent Compatibility

The root [`AGENTS.md`](AGENTS.md) defines shared project conventions. Skills can also be reused with other coding agents that support project instructions or skill packages.

| Agent | Setup |
| --- | --- |
| OpenCode | Use the included [`opencode.json`](opencode.json) |
| DeepSeek / Codex | Native project-instruction and skill support |
| Cursor | Keep `AGENTS.md` and copy `.agents/skills/` to `.cursor/skills/` |
| Claude | Copy the contents of `AGENTS.md` to `CLAUDE.md`, then copy `.agents/skills/` to `.claude/skills/` |

## Godot Framework

[`zfoo/`](zfoo/) is the reusable Godot framework that powers GAI. Highlights:

- **AI** — `OpenAiClient` with non-stream and SSE streaming chat, tool calls, and `CancelScope`
- **HTTP & processes** — `HttpHelper` / `AsyncHttp` (redirects, proxy, cancellation); `OSUtils` for sync/async subprocesses
- **Concurrency** — `ExecutorHelper` (single-thread and worker-pool queues), `ConcurrentArrayList`, `ConcurrentMapInt`
- **Assets** — `ResourceHelper` / `AsyncResourceLoader`, plus `ImageHelper` and `VideoHelper` for external files
- **Runtime** — TCP/WebSocket sessions and `Router`, audio (`Audio`, `Audios`, `AudioRecorder`), scene transitions, hot-update PCK flow
- **App plumbing** — `Log` / `LoggerHelper`, `Setting`, `SchedulerBus`
- **I18n** — locale in `Setting`, `I18n.t()`, `locale_changed` for UI refresh
- **UI** — theme tokens (`ThemeColor`, `Colors`, `FileColors`), control styles, `DisplayScale`, `ScreenUtils` (window / active monitor, usable area), feedback (`Alert`, `DesktopToast`, `PopupWindow`, `CommonWindow`, `ImagePreviewWindow`); see **UI** in [`AGENTS.md`](AGENTS.md)
- **Tests** — `UnitTest` and `IntegrationTest` under `zfoo/gdtest/`

Agent-facing API notes and GDScript conventions live in [`AGENTS.md`](AGENTS.md).

To reuse it in another Godot project:

1. Copy `zfoo/` into the target project.
2. Register the following entry under **Project → Project Settings → Autoload**:

| Name | Path |
| --- | --- |
| `GodotFramework` | `res://zfoo/GodotFramework.tscn` |

The Autoload exposes the global class name `gdf`. Call `gdf.shutdown()` for a clean exit (HTTP, subprocesses, and executors are stopped automatically).

## Repository Structure

```text
gai/
├── agent/           # Desktop coding agent and visual workflow editor
├── cli/             # Command-line examples for individual skills
├── cpp/             # godot-cpp GDExtension (C++ native classes)
├── .agents/skills/  # Agent skill definitions and instructions
├── .ai/             # Skill implementation scripts
├── .dependency/     # Isolated runtimes, models, and external tools
├── zfoo/            # Reusable Godot framework
└── test/            # Unit and integration tests
```

See [`cpp/README.md`](cpp/README.md) for build and usage details.

## License

This project is released under the terms described in [LICENSE](LICENSE).
