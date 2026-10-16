# SkillsWorkflow

A ComfyUI-style skill workflow editor for this repository. Each `.ai/` skill is a node; matching input/output types can be wired together into workflows that you can save, reopen, and run.

## Running

Open the project in the Godot editor and run `agent/app/workflow/Workflow.tscn`.

## Features

| Area | Description |
|------|-------------|
| **Skill library** | Left sidebar tree grouped by category (Input, Audio, Image, Video). Double-click a skill to add it to the canvas. |
| **My workflows** | Saved workflows appear at the bottom of the sidebar. The app scans `user://workflows/` on startup. Double-click a name to load it. |
| **Connections** | Drag from an upstream output to a downstream input. Only same-type ports connect (`audio`, `image`, `video`, `text`, `folder`). |
| **Manual inputs** | Unconnected ports accept a path typed in the node, or chosen with the `…` browse button. |
| **Source nodes** | Input nodes (Audio Input, Image Input, etc.) are workflow entry points. |
| **Batch (For Each)** | Takes a folder, a glob (e.g. `*.wav`), and an output type; every downstream step runs once per matched file. |
| **Save / Open** | Workflows are stored as `.workflow.json` under `user://workflows/`. Toolbar buttons open the file dialog. |
| **Run** | Executes skill scripts from `.dependency/` in topological order. Progress and logs appear in the UI. |

Toolbar: **New**, **Open**, **Save**, **Delete Node**, language toggle, **Log**, **Run**.

## Project layout

```
gui/
├── SkillsWorkflow.tscn      # Main scene
├── SkillsWorkflow.gd        # Shell: toolbar, sidebar, dialogs
├── WorkflowEvents.gd        # GUI event bus (WorkflowEvents.events.*)
├── ui/
│   ├── SkillGraphEdit.gd    # Graph canvas: nodes, connections, load/save
│   └── nodes/               # Node UI classes
├── config/
│   ├── graph_nodes.json     # Node defs: ports, categories, CLI templates
│   └── GraphNodesConfig.gd  # Loads JSON, creates node instances
├── workflow/
│   ├── WorkflowDocument.gd
│   ├── WorkflowNodeData.gd
│   ├── WorkflowConnection.gd
│   └── WorkflowManager.gd   # Save/load, scan user://workflows/
├── pipeline/
│   ├── PipelineRunner.gd    # Topological run, batch fan-out
│   ├── SkillCommandBuilder.gd
│   └── ...
├── locale/
│   └── locale/
│       ├── zh.json          # Default UI strings
│       └── en.json
└── test/
```

## Adding and configuring nodes

Node structure lives in `gui/config/graph_nodes.json` (ports, category, CLI flags). **Display text** lives in `gui/locale/*.json`. For most new skills, edit those two JSON files only — no new GDScript class is required.

### Class hierarchy

| Layer | Class | When you need it |
|-------|-------|------------------|
| Config | `graph_nodes.json` + `locale/*.json` | Every node: ports, category, CLI; labels in locale |
| Skill node | `PathInputSkillNode` | Default skill UI; ports generated from JSON |
| Source node | `InputSourceNode` | All “XX Input” source nodes |
| Control node | `BatchForEachNode` | Batch node extra controls (glob, output type) |
| Custom subclass | Extend the bases above | Only when overriding `build_node()`, extra manual fields, or special pipeline behavior |

`GraphNodesConfig.create_node()` picks the instance: source → `InputSourceNode`, control → `BatchForEachNode`, skill → `PathInputSkillNode`.

## Nodes and ports

Each node has **inputs** (`inputs`) and **outputs** (`outputs`):

| Node kind | Typical inputs | Typical outputs |
|-----------|----------------|-----------------|
| Source | none | one (file or folder path) |
| Skill | one or more | one |
| Control | one or more | one or more |

Ports are identified by **`id`**, not by `type`. Multiple inputs of the same type use different ids (e.g. `track_a`, `track_b`). CLI templates use `{port_id}` placeholders for each input.

Port types: `audio`, `image`, `video`, `text`, `folder`. Connections require matching types. Each input port accepts at most one upstream wire; other values can be filled manually.

## Localization

| File | Role |
|------|------|
| `config/locale/zh.json` | Simplified Chinese (default) |
| `config/locale/en.json` | English |
| `zfoo/i18n/I18n.gd` | Register JSON strings with Godot `TranslationServer` |

String keys:

- Workflow UI, dialogs, alerts, and pipeline messages: `workflow.*`
- Sidebar categories: `workflow.category.*`
- Node titles: `workflow.node.{id}` or `workflow.node.{skill}` (English UI often uses the id, matching the `.ai/` folder name)
- Port labels: prefer `workflow.node_port.{id}.{port_id}`, then `workflow.port.{port_id}`, then `workflow.port_type.{type}`

Switch language (refreshes toolbar, sidebar, and canvas nodes):

- Language button left of **Log** (`EN` on Chinese UI, `中文` on English UI)
- Or call `TranslationServer.set_locale("en")` and rerun the UI refresh logic

## Pipeline notes

- Default skill output path: `<input-dir>/<skill-id>/…`
- **Batch example:** `Folder Input → For Each (*.wav, output type = audio) → Audio to WAV`
- One workflow supports one batch node; all steps after it fan out over matched files
- Interactive skills (e.g. Gradio UI) are not in the node library
- Multi-output skills, non-standard CLIs, or skills needing special path prediction are omitted until generic pipeline support exists; they can be re-added via JSON later
