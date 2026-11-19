---
name: html-animation-to-frames
description: Renders one self-contained HTML animation into PNG frames in real time through the local gai web animation API, waits for rendering to finish, and verifies the generated frame package. Use when the user wants to render, capture, export, or convert an HTML animation into PNG image frames, including HTML produced by html-text-to-animation or storyboard-shot-to-html.
---

# HTML Animation to Frames

Render one HTML animation through the already-running local web service and verify its output.

## Rules

Read and follow [dependency-manager](../dependency-manager.md). Run the bundled script through the repository Python interpreter.

- Require one HTML file path and one output directory.
- Do not start the web service or control the browser directly. The service must already be running.
- Resolve `HOST` and `PORT` from `web/.env`, then fall back to `web/.env.example`. Use `127.0.0.1` only when neither file defines `HOST`; require `PORT` from one of the files.
- Do not modify the HTML or delete an existing animation directory.
- Do not add seek, pause, or frame-stepping hooks to the HTML: the service captures the animation while it plays.
- Wait until the service reports `completed` or `failed`; receiving the animation name does not mean rendering has finished.
- Report the verified animation directory when successful. Report the service error when rendering fails.

## Run

From the repository root:

```bash
.dependency/python/python .ai/html-animation-to-frames/render.py --html path/to/animation.html --output path/to/frames
```

| Flag | Meaning |
|------|---------|
| `--html` | Path to the self-contained HTML animation |
| `--output` | Parent directory in which the animation directory is created |

The service derives the animation name from the HTML filename. For `demo.html`, frames and `manifest.json` are written under `<output>/demo/`.

## HTML Contract

The page must autoplay its animation as soon as it loads. The renderer waits for the `load`
event, `document.fonts.ready`, and the first painted frames, then captures the live page at
60 FPS in real time; it never seeks, freezes, or drives the animation.

Declare the duration in seconds with `<meta name="animation-duration" content="5">`.
The API also accepts an optional positive `duration` in seconds, which overrides the meta value.
No other source of duration is supported.

Because capture is real time, the animation must be driven by elapsed time rather than by a fixed
number of frames, and must already be visible when the load event fires.

The renderer uses the host's largest physical display resolution and 60 FPS. The script submits the task, polls its status, then verifies the completed manifest, frame count, and first and last PNG files.

## Tests

```bash
.dependency/python/python .ai/html-animation-to-frames/test_render.py
```
