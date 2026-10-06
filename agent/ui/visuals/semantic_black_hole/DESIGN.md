# Semantic Black Hole

## Design Intent

Semantic Black Hole presents an agent run as information being absorbed, compressed, transformed, and released. Its silhouette and motion are intentionally distinct from the graph-oriented visual effects and from Neural Aurora's atmospheric field.

The central metaphor is semantic gravity:

- The event horizon is the compressed internal model state.
- The accretion disk is active context being reorganized.
- Spiral dust is user input, history, files, and intermediate information.
- Gravitational interference represents reasoning intensity.
- Relativistic jets represent user-facing output.
- A satellite wormhole represents an external tool invocation.
- Green return packets and red disk disturbances represent tool success and failure.
- Final collapse and Hawking-like dust represent completion.

## Architecture

The effect uses one full-screen `ColorRect`, one `canvas_item` shader, and one regular `Label` for the active tool name.

`SemanticBlackHole.gd` converts discrete `VisualEffect` callbacks into persistent targets, transient envelopes, and monotonic timelines. `SemanticBlackHole.gdshader` owns all spatial rendering. The shader loads asynchronously through `ResourceHelper.async_load()`.

Do not sample or distort the real chat interface. The gravitational lens is drawn inside the effect itself so text remains readable and rendering remains portable.

## Event Contract

| Event | State | Visual response |
|---|---|---|
| Agent start | Raise gravity and disk energy | A dark horizon forms and gathers a thin disk |
| Chat entry | Increase context density sublinearly | More semantic dust spirals inward |
| Reasoning chunk | Raise gravity, disk energy, and reasoning density | Faster disk detail and a broader interference halo |
| Content chunk | Sustain jet energy | A warm bipolar information jet leaves the core |
| Tool start | Open a wormhole at a stable tool-derived angle | A satellite ring and bridge appear with the tool label |
| Tool success | Start the return envelope | A green packet travels back toward the horizon |
| Tool failure | Start the failure envelope | A red irregular shock crosses the disk |
| Turn start | Reverse target rotation | The disk decelerates through zero and changes direction |
| Agent end | Advance completion for 2.3 seconds | Matter collapses, the singularity flashes, then sparse dust evaporates |

## Composition Order

The shader composes semantic dust, the back half of the disk, lensing, the event horizon, the front half of the disk, reasoning interference, jets, the wormhole bridge, result feedback, and completion. Preserving this order is what makes the flat disk read as a volume around an opaque body.

The horizon diameter should remain below roughly 22 percent of the viewport's short edge, the disk below roughly 55 percent, and final alpha below full opacity. Those constraints protect transcript legibility.

## State and Timing

Persistent values use current/target pairs with exponential followers. Event envelopes decay at rates measured per second. `completion` advances monotonically from zero to one.

Successful tool return keeps travel progress separate from brightness. The packet remains visible throughout its 1.15-second journey, pauses on the photon ring for a short absorption beat, and only then fades. Do not derive packet opacity from the inverse of travel progress; doing so makes the result disappear before it reaches the horizon.

`COMPLETE_SECONDS` must match the completion timeline expected by the shader and the delay returned to `VisualControl`. The longer 2.3-second ending is intentional: it leaves enough time to read the collapse, flash, and evaporation as separate beats.

Tool placement comes from a stable hash of the tool name. This creates spatial memory across runs; do not replace it with random placement unless the design language changes deliberately.

## Performance

- Keep the effect to one full-screen shader pass.
- Do not allocate particles or nodes in `_process()`.
- Upload uniforms only through `set_shader_parameters()`.
- Prefer procedural dust to real per-token particles.
- If a low-quality mode is needed, reduce dust detail and noise sampling before removing the front/back disk construction.
