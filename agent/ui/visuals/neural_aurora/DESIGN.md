# Neural Aurora

## Design Intent

This effect presents an agent run as a digital sky waking up. It deliberately avoids drawing flowcharts, trees, or tool nodes, so it remains visually distinct from `Reasoning Tree`, `Tool Constellation`, and `Context Memory River`.

The core visual vocabulary is:

- The central light represents the agent's conscious core.
- Aurora curtains represent the persistent context field.
- Fine, high-frequency ridges represent reasoning activity and neural impulses.
- Warm expanding waves indicate that the agent is producing user-facing content.
- Radial electric arcs indicate that the agent is reaching outside its core to call a tool.
- A green return wave means a tool result succeeded; red cracks mean it failed.
- A flow reversal marks the beginning of a new turn.
- A contracting ring followed by particle-like dissolution marks the end of the agent lifecycle.

## Architectural Boundary

The effect consists of one full-screen `ColorRect`, one `canvas_item` shader, and one tool-name `Label`.

- `NeuralAurora.gd` listens to the `VisualEffect` lifecycle, maintains smoothed state, and uploads uniforms.
- `NeuralAurora.gdshader` renders all large-area imagery: flow, clouds, pulses, waves, arcs, cracks, and dissolution.
- The tool name remains a regular `Label` to preserve font quality, theme integration, scaling, and readability.
- The shader is loaded asynchronously through `ResourceHelper.async_load()` so selecting the effect does not block the main thread. Events received during loading remain stored in controller state.
- Do not create large node or particle graphs for clouds, neural points, or completion dust. The single-shader design is essential to the effect's stable performance and low management overhead.

## Event Mapping

| Agent event | CPU state change | Screen result |
|---|---|---|
| `on_agent_start` | Set `target_energy` to `0.72` with low `detail` | The center illuminates and the aurora slowly unfolds |
| Reasoning `on_message_update` | Raise energy and detail to `1` | Flow activity increases and fine neural ridges appear |
| Content `on_message_update` | Reset `output_pulse` | A warm wave expands outward from the center |
| `on_tool_execution_start` | Start `tool_pulse` and derive an angle from the tool name | An arc shoots toward the edge and the tool name appears at the top |
| Tool success | Start `success_pulse` | A green ring flows back toward the center |
| Tool failure | Start `failure_pulse` | Red radial cracks flash briefly |
| `on_turn_start` | Invert `target_direction` | The entire flow field decelerates and reverses |
| `on_agent_end` | Advance `completion` | The aurora contracts into a ring, dissolves into particles, and becomes transparent |

## State Model

State falls into three categories:

1. Persistent state: `energy`, `detail`, and `direction`. Each uses a current/target pair and an exponential follower so transitions remain consistent across frame rates.
2. One-shot envelopes: `output_pulse`, `success_pulse`, and `failure_pulse`. An event sets the value to `1`, after which it decays at a rate measured per second.
3. Monotonic timelines: `tool_pulse` travels from the center to the edge; `completion` advances from `0` to `1` and never reverses.

`COMPLETE_SECONDS` controls the shader completion duration. `wait_for_agent_end()` waits for that timeline after draining queued tool visuals, so changing the duration must keep the controller and shader composition aligned.

Tool events use a visual queue because real tools may finish in only a few frames. Each call owns at least `MIN_TOOL_PLAY_SECONDS`, allowing its arc head to reach the edge, followed by `TOOL_RESULT_HOLD_SECONDS` for the green return or red crack result. Tool labels remain visible throughout the call and result hold, using the accent color while running and semantic success/error colors for the result. `wait_for_agent_end()` drains this queue before starting completion so the final tool is never cut off.

Failure is deliberately staged rather than switched on as a full-screen mask. `failure_progress` first creates a localized impact at the tool arc endpoint, expands a short shock ring, and then reveals radial cracks from the outer field toward the core over `FAILURE_REVEAL_SECONDS`. Keep failure intensity and reveal progress separate so timing changes do not reintroduce an abrupt full-screen pop.

## Shader Composition

`fragment()` composes the following layers in order. Later layers may cover or intensify earlier layers:

1. Broad domain-warped FBM clouds and aurora curtains.
2. The central light and its energy glow.
3. Neural ridges controlled by `detail`.
4. Warm content-output waves.
5. The tool arc and its travelling head.
6. The success return wave or failure cracks.
7. The completion ring, noise-based dust, and final transparency.

Colors are injected from `ThemeColor.accent_theme_color()`, `ColorBase.success`, and `ColorBase.error`. Derive new colors from theme tokens whenever possible; do not bake a background color for one specific theme into the shader.

## Performance Constraints

- The primary costs are the number of full-screen pixels and the five-octave FBM. CPU state updates are inexpensive.
- For a future low-quality mode, reduce the `fbm()` loop from five octaves to three or four before making other compromises.
- Avoid additional full-screen shader passes and do not allocate objects in `_process()`.
- All uniforms are uploaded through `set_shader_parameters()`. New visual channels should use the same synchronization point.
- The alpha ceiling intentionally stays below `1` so the chat interface remains legible. Do not turn the effect into an opaque background.

## Extension Guidelines

Use this sequence when adding a visual response to another event:

1. Add one clearly named, normalized envelope to the controller.
2. Trigger it from the relevant lifecycle callback.
3. Smooth or decay it in `_process()` using a frame-rate-independent formula.
4. Upload it only through `set_shader_parameters()`.
5. Add an independent composition layer in the shader and document it in the event table above.
6. Add logic coverage to `agent/test/visual/unit/NeuralAuroraTest.gd`; inspect visual changes manually with the shared preview scene.

The tool direction is derived from a stable hash of the tool name, so the same tool fires in approximately the same direction each time. This creates a small but useful visual memory cue and should not be replaced with per-call randomness.
