# HTML Animation to Frames

Run commands from the repository root. The gai web service must already be running. Its `HOST` and `PORT` are resolved from `web/.env`, then `web/.env.example`; only `HOST` has a final `127.0.0.1` fallback.

## Unit tests

```powershell
.dependency/python/python.exe .ai/html-animation-to-frames/test_render.py
```

## Render an animation

```powershell
.dependency/python/python.exe .ai/html-animation-to-frames/render.py --html C:/animations/demo.html --output C:/output/frames
```

Expected output directory:

```text
C:/output/frames/demo/
```
