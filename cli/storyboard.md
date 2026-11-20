# storyboard

Agent-only skill — write narration with the complete Chinese section first and
the complete English section second. No bundled script under `.ai/`.

Delivery:

| Mode | Behavior |
|------|----------|
| User explicitly gives an output file | Write the full narration markdown to that path |
| User explicitly gives an output directory | Create `narration-script.md` there |
| No output destination | Deliver the full narration in chat only |

Downstream CLI (after storyboard exists):

```bash
.dependency/index-tts/.venv/Scripts/python.exe .ai/storyboard-tts/synthesize.py --storyboard path/to/storyboard.md --voice .ai/test/audio/han.wav --fp16 --report
```
