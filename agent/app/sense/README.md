# Sense voice input

Global push-to-talk voice input for the agent app. Hold the configured shortcut to record and release it to transcribe. The resulting text is copied and pasted directly into the foreground input control without opening another panel.

## Flow

1. Hold the shortcut to start `AudioRecorder` and show `SenseWave` in the active screen's usable-area center.
2. Release to stop recording and run the local SenseVoice transcription script.
3. Dismiss the wave, put the transcription on the clipboard, briefly allow clipboard propagation, and call `NativeOS.paste_clipboard()` to send Ctrl+V to the original input control.

Failures are logged and leave the target input unchanged. The global shortcut is configured under **Settings → Shortcuts**.

## Stack

| Piece | Role |
|-------|------|
| `GlobalHotkey` | Receive the configured press and release while the app is unfocused |
| `AudioRecorder` | Record microphone input as PCM16 WAV |
| Local SenseVoice script | Convert the recording directly to text |
| `SenseWave` | Show recording and transcription state without taking focus |
| `NativeOS` | Paste clipboard text into the foreground application |

## Files

```
agent/app/sense/
├── SenseInput.gd    # Push-to-talk, transcription, and direct paste
├── SenseWave.gd     # Recording/transcription wave overlay
└── README.md
```
