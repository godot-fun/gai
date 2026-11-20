# HTML Animation to Video

Run commands from the repository root. The gai web service must already be running with a visible (non-headless) browser window. Its `HOST` and `PORT` are resolved from `web/.env`, then `web/.env.example`; only `HOST` has a final `127.0.0.1` fallback.

Recording needs Windows, a working NVENC encoder, and an NVENC-capable GPU. Any Windows display scale works (the recorder is DPI aware). The script records the secondary display and moves the browser onto it. Do not touch the mouse or keyboard while a recording runs, and leave other windows off the recorded display.

## Unit tests

```powershell
.dependency/python/python.exe .ai/html-animation-to-video/test_record.py
```

## Record an animation

The page must stay paused on its first frame and start on `Space`; the recorder opens it, switches the window to fullscreen, starts capture, and then presses `Space` through the web service.

```powershell
.dependency/python/python.exe .ai/html-animation-to-video/record.py --html C:/animations/demo.html
```

Expected output file, beside the HTML file:

```text
C:/animations/demo.mp4
```

Write it somewhere else instead:

```powershell
.dependency/python/python.exe .ai/html-animation-to-video/record.py --html C:/animations/demo.html --output C:/output/videos
```

