---
name: html-animation-to-video
description: Records one self-contained HTML animation into an MP4 by screen-capturing the browser window with FFmpeg Desktop Duplication and NVENC. Use when the user wants to export, capture, record, or convert an HTML animation into a video file, including HTML produced by html-text-to-animation.
---

# HTML Animation to Video

Open one HTML animation in the already-running local browser, freeze it on its first frame, and
record the screen into a single MP4 once Space starts the timeline.

## Rules

Read and follow [dependency-manager](../dependency-manager.md). Run the bundled script through the repository Python interpreter.

- Require one HTML file path. The output directory is optional and defaults to the directory that holds the HTML file.
- Do not start the web service or the browser. Both must already be running; the script only asks the service to open the page and to press Space.
- The service must run with a visible browser window (`BROWSER_HEADLESS=false`). In headless mode `/animation/open` fails with `HEADLESS_BROWSER` and the script stops before recording.
- Windows only: capture uses the Desktop Duplication API (`ddagrab`). Encoding probes `hevc_nvenc`, then `h264_nvenc`, and falls back to CPU `libx264` when no NVENC encoder answers.
- The page must stay paused on its first frame and declare its duration with `<meta name="animation-duration" content="15">`, replacing `15` with the real duration in seconds. The service reads it from the loaded page and returns it, so the recorder never parses the HTML; `--duration` overrides it.
- Do not add play buttons, seek, pause, or frame-stepping hooks: the recorder starts the page with Space and the timeline runs once.
- Run one recording at a time: playback reuses a single browser tab, so a parallel run would navigate the tab away from the animation being recorded.
- The script records the secondary display and moves the browser onto it, so the primary display stays usable. Keep that display clear and leave the machine alone until the script reports completion: the recorder captures screen pixels, so any window that covers the browser, a screen saver, or a display that sleeps ends up in the video.
- The script switches the window to browser fullscreen (F11) so the page owns the whole monitor, and re-raises it above other windows. A window that is fullscreen on the other display is taken out of fullscreen first, because the window manager ignores a move while fullscreen. If the window stays windowed, the script records the client area and warns; a rectangle that falls outside the recorded display stops the run with an error.
- Anything up to a 4K capture works at any Windows display scale: the recorder is DPI aware, so a 150% scale still captures the full monitor.
- An existing `<html stem>.mp4` is replaced without asking, so mention that when reporting the result.
- Leave the desktop as it was found: the script exits fullscreen and closes the playback tab when it finishes, whether the recording worked or not.

## Run

From the repository root:

```bash
.dependency/python/python .ai/html-animation-to-video/record.py --html path/to/animation.html
```

| Flag | Meaning |
|------|---------|
| `--html` | Path to the self-contained HTML animation |
| `--output` | Directory for the recorded MP4 (default: the HTML file's directory) |
| `--duration` | Seconds, overriding the duration declared by the page |
| `--fps` | Capture frame rate (default `60`) |

The MP4 is written to `<output>/<html stem>.mp4`, next to the HTML file when `--output` is omitted.

## How it works

1. `POST /animation/open` loads the page and answers once its paused first frame is on screen, so
   browser startup, page load and font loading never land inside the recording.
2. The script moves the browser onto the recorded monitor, switches it to fullscreen and waits 3 s for
   the transition and the page relayout to settle, then reopens the page so its paused first frame is
   rendered at the final size. FFmpeg starts on the monitor at the requested frame rate.
3. `POST /animation/play` presses Space. The page starts its timeline on that key and on the first
   frame it paints afterwards.
4. Recording runs for the press offset plus the declared duration and a 0.4 s margin, so the last
   visible change is always inside the file.
5. The paused page is still until Space arrives, so the first frame with enough visibly changed
   pixels compared with the frame before it is the animation starting on screen. The script masks
   per-pixel differences above encoder noise on a 480 px thumbnail of the recording (a second of
   analysis, not a second per second), so a quiet recording scores zero and even a small overlay
   popping registers; it cuts there and keeps exactly the declared duration, which also absorbs the
   compositor lag between the key and the first visible frame.
   A page may open too quietly for that test: thin rules darkening or digits ticking under the
   thumbnail stay below the threshold, so the first detected frame can come a second after the key.
   The paused page and the animation's first frame are the same image, so the script then cuts on the
   key press instead — that keeps the whole declared timeline rather than dropping the quiet opening
   and holding the last frame for as long as the detection was late.

A browser needs a few hundred milliseconds to present its first frame after an idle screen; the
cut lands on that first visible frame, so the opening of the animation is never lost and no previous
page can appear in the output.

No per-frame image files are written, so a 15 s 4K animation costs one MP4 instead of 900 PNG frames.

## HTML contract

The page must fill the monitor: a full-viewport stage, no scrollbars, no letterboxing around the animation. Drive animation from elapsed time (`performance.now()` or CSS animations), never from a frame counter, because capture pacing depends on the display, not on `requestAnimationFrame` counts.

- Render the animation's first frame and wait for `Space`. Start the timeline on the first frame painted after the key, not on the key event.
- Keep the paused state visually still: no motion, no blinking caret, no running ambience. The recorder detects the start as the first frame that changes, so a preview animation would be mistaken for it.
- Keep presenting while paused (redraw the paused frame from a `requestAnimationFrame` loop): a page that stops painting needs a moment to wake up, and that wake-up would swallow the opening of the animation.
- Prefer system font stacks. A web font that finishes loading after the first painted frame shows fallback glyphs at the start of the recording.

## Tests

```bash
.dependency/python/python .ai/html-animation-to-video/test_record.py
```
