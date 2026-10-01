# Sense input method

Global push-to-talk sense input for the agent app. **Hold Ctrl+Alt+Z** to record — works even when the Godot window is in the background. **Release** to stop, transcribe, and pick a refined candidate.

## Flow

1. **Hold Ctrl+Alt+Z** → start microphone capture (`AudioRecorder`), show the volume sine wave (`SenseWave`), and quietly kick off a monitor screenshot (`NativeOS.capture_screen`) + VLM OCR (`VLMServer.async_image_to_text`) in parallel
2. As soon as screen OCR is ready: **remote** fires an early diverge chat from the UI alone; **local** marks OCR ready (compose later overwrites diverge after expand; empty ASR falls back to OCR text)
3. **Release** → keep the wave fixed, stop capture (if mic started), soft-fail ASR into logs only — **no error toasts**
4. Always dismiss the wave and open `SensePicker` on the **same pin** as the wave (`fixed_anchor`), with the **same logical width** (`SenseWave.WAVE_WIDTH`) and the same top-left (picker grows downward). Voice fills immediately; compose + diverge fill in parallel. Compose waits up to **3 s** for screen context.
5. Picker briefly steals focus for keyboard nav (`↑`/`↓` among ready rows + cancel, `Enter` confirm, `1`–`5` / keypad jump to a ready slot, `Esc` cancel). Click a ready row also works. On close it `NativeOS.restore_foreground_window()`, then clipboard + `NativeOS.paste_clipboard()` (Ctrl+V into the target field). Cancel / Esc dismisses without pasting.
6. A desktop toast reports the pasted preview (success only). Busy-in-progress may warn; ASR / mic / save failures never toast — diverge prediction guarantees a result.

### Local vs remote (`SenseInput.use_local_llm`)

| | Local (`use_local_llm = true`, default) | Remote (`use_local_llm = false`) |
|--|--|--|
| Chat | `VLMServer` (MiniCPM-V) | `OpenAiClient` via `ApiSetting` |
| Prompts | `SensePromptLocal` (short, clamped) | `SensePrompt` (rich) |
| Compose | Sequential: correct → optimize → expand → diverge | One-shot JSON with correct/optimize/expand |
| Diverge | Last compose step (expand + screen); OCR fallback if no voice | Early screen-only chat (parallel with compose) |
| Screen OCR | Always `VLMServer` (vision) | Always `VLMServer` (vision) |

## Input beacon

`SenseWave` is a transparent, always-on-top, unfocusable native `Window` (same pattern as `DesktopToast`). Design size is **512×64 at 2K**; other screens use `DisplayScale.compute_screen_scale` (usable width / 2560). Newest mic level enters on the **right**; older amplitudes drift **left**.

On show it calls `SenseCaretLocator.resolve_anchor()` **once** and stays there:
- **Godot focused** (`godot_focus_anchor`: focused window → `TextEdit` caret in screen space, else mouse). OS caret is skipped so UIA cannot pin the wave to the wrong screen.
- **Background** → `query_os_caret` (plausibility-filtered), else center of the screen under the mouse.

Clicks pass through (`mouse_passthrough`). During transcription / compose the wave keeps a gentle fixed amplitude and slower scroll. Size uses `DisplayScale.compute_screen_scale`, not `DisplayScale.compute_ui_scale`.

## Stack

| Piece | Role |
|-------|------|
| `GlobalHotkey` (GDExtension) | OS-level Ctrl+Alt+Z press + release while unfocused — see [`cpp/README.md`](../../../cpp/README.md) |
| `NativeOS` (GDExtension) | Foreground remember/restore, Ctrl+V paste, caret screen position, monitor screenshot — see [`cpp/README.md`](../../../cpp/README.md) |
| `SenseCaretLocator` | Locate pin point (Godot caret / OS caret / screen center) |
| `SenseWave` | Volume sine wave, pinned once via `SenseCaretLocator.resolve_anchor` |
| `SensePicker` | Five-candidate selection sheet (focusable for ↑↓/Enter/Esc; restore foreground then paste) |
| `AudioRecorder` | Microphone → PCM16 WAV |
| `AudioToTextTool` | Local SenseVoice transcription |
| `VLMServer` | Local MiniCPM-V: screenshot OCR; local compose + diverge when `use_local_llm` |
| `ApiSetting` / `OpenAiClient` | Remote compose + diverge when not `use_local_llm` |
| `SensePromptLocal` | Short local prompts + input clamps (zh / en by app locale) |
| `SensePrompt` | Rich remote prompts / one-shot compose JSON (zh / en) |

## Files

```
agent/app/sense/
├── SenseInput.gd           # Push-to-talk + screen sense + compose + paste
├── SensePromptLocal.gd     # Local VLM prompts (short / sequential)
├── SensePrompt.gd          # Remote LLM prompts (rich / one-shot JSON)
├── SenseCaretLocator.gd    # Locate caret / OS caret / screen-center pin point
├── SenseWave.gd            # Input-anchor volume sine-wave overlay
├── SensePicker.gd          # Candidate selection sheet (keyboard + mouse)
├── test/                   # Unit tests for anchor + beacon + compose helpers
└── README.md
```

Wired from `Agent.gd` (`sense_input.setup()` / `shutdown()`).
