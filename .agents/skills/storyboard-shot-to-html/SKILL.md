---
name: storyboard-shot-to-html
description: >-
  Turns a storyboard shot (video prompt + narration) into a self-contained
  fullscreen HTML CSS animation for the browser. Analyzes VO/narration, searches
  related facts and usage cues, then builds a rich layered stage (camera,
  subject, secondary UI, light, micro-detail) with Fullscreen API and Space-to-play.
  Use when the user wants storyboard-shot-to-html, HTML animation preview,
  prompt-to-HTML, storyboard to HTML, prompt animation demo, narration visualization, fullscreen preview,
  Space to play, or a web demo of a video prompt / shot.
---

# Storyboard Shot → HTML

Turn **one shot** (video prompt + narration) into a **single-file HTML** animation you can open in a browser — a motion sketch of the intended frame, not a real video render.

Companion to **[storyboard](../storyboard/SKILL.md)**. Does **not** call video/image generation APIs.

## Inputs

Accept any of:

| Input | How to use |
|-------|------------|
| Storyboard `.md` + shot id (`01`, `Shot 02`, …) | Parse that shot’s `Video prompt`, `Chinese` / `English`, `Visual`, `Camera`, `Duration`, Visual Style |
| Pasted shot block | Same fields if present |
| Raw video prompt (± narration) | Prompt = visual source; narration = meaning layer to research |

If multiple shots and no id → ask once, or do **Shot 01** only when the user clearly wants a quick sample.

## Delivery

| Mode | Behavior |
|------|----------|
| User gives an `.html` path | Write there |
| User gives a directory | Write `<dir>/shot-<id>-preview.html` (`shot-01-preview.html` if no id) |
| Storyboard path known, no output path | Write next to the `.md`: `<stem>-shot-<id>-preview.html` |
| Raw prompt only | Write `test/manual/<slug>-preview.html` (or user-named file) |

**Rules:**

- Always **write the full HTML file** (UTF-8). Chat: short confirm only (path, shot id, research notes, how to open).
- Prefer **one self-contained `.html`** (inline CSS/JS). No build step or network dependency. Use system font stacks by default; if the user explicitly wants a web font, treat it as an optional online enhancement and provide a readable local fallback.
- **Fullscreen by default** (see below) — first paint is the stage filling the browser; no document scroll of title/meta under the frame.
- After write: **open in the system browser** (`Start-Process` / `open` / `xdg-open`). If `file://` is flaky, serve the parent dir with a tiny static server and open `http://127.0.0.1:<port>/<file>`.
- Never overwrite the storyboard `.md`.

### Fullscreen (required)

The preview must play as a **full-viewport cinematic stage**, not a letterboxed card on a scrolling page.

| Requirement | Detail |
|-------------|--------|
| Viewport fill | `html, body { height:100%; overflow:hidden }`; stage covers **100vw × 100vh** |
| Aspect | Keep storyboard aspect (default **16:9**) with **cover** (crop) or letterbox on black — prefer **cover** so the frame fills the screen |
| No below-fold chrome | Title, tags, original prompt must **not** sit under the stage in normal flow |
| Overlay meta | Put prompt / research in a **hidden overlay** (`I` or `?` to toggle; `Esc` closes). **Do not** burn VO/narration onto the stage — narration is for analysis only, not on-screen text |
| **Space to play** | The **main narrative timeline** stays paused on load (first frame / idle pose). **`Space`** starts it **once**. Do not autoplay the story. Tiny non-narrative ambience may run before Space only when it does not advance or reveal the shot. Hint text: `Space to play · Click / F fullscreen · I prompt` |
| **Play once** | Shot timeline is **one-shot** — no `infinite` / `alternate` loop on the main beat. When duration ends, **hold the final frame** (`animation-fill-mode: forwards` or equivalent). Do **not** restart on a second `Space`, and do not auto-replay |
| Browser Fullscreen API | On click (or `F`), call `element.requestFullscreen()` on the stage root. Show a brief hint until entered (`Click / F fullscreen · Space to play`). `Esc` exits native fullscreen |
| Open behavior | After writing the file, open it so the user lands on the fullscreen-ready **paused** page; wait for `Space` to play |

## Workflow

```
Task Progress:
- [ ] Parse shot (prompt + VO + camera/duration/style)
- [ ] Analyze narration → concepts to ground
- [ ] Search related info / usage (when needed)
- [ ] Plan motion layers (camera / subject / secondary / light / micro) + timing beats
- [ ] Design rich stage from prompt + research (depth planes, staggers, payoff hold)
- [ ] Write HTML; open in browser
- [ ] Chat: path + what the demo shows
```

### 1. Parse the shot

Extract:

- **Video prompt** (primary visual / motion spec)
- **Chinese** / **English** VO (meaning, pacing; `(no VO)` = skip that language)
- **Visual**, **Camera**, **Duration**, piece-level **Visual Style** when available

Map duration to animation timing when sensible (`~5s` → ~5s **one-shot** timeline, then hold). Playback starts only on **`Space`** (paused until then); never loop or auto-replay.

### 2. Analyze narration (required)

From VO, list **concrete concepts** that affect what the viewer should understand. If the shot has no VO, state that narration analysis is not applicable and extract any factual concepts from the video prompt instead.

- Product / feature / API / workflow names
- Places, eras, UI metaphors, audience takeaway
- Claims that need accurate depiction (do not invent)

If VO only restates mood already in the prompt, research may be light — still state that explicitly in chat.

### 3. Search related info / usage

When concepts are factual, technical, or product-specific:

1. Use **WebSearch** / **WebFetch** (or project docs) for short, trustworthy cues: what it is, how it’s used, typical UI/visual metaphors.
2. Fold **only** what helps the HTML stage (labels, layout metaphors, correct terminology, iconic shapes).
3. Do **not** invent logos, prices, legal claims, or competitor branding.
4. If search fails or materials already suffice, proceed with prompt-only visuals; note gaps briefly.

Skip heavy research for pure mood/atmosphere shots with no domain claims.

### 4. Build the HTML animation

Goal: **one composition** that reads as the shot at first viewport — animated stand-in for the video prompt. Aim for a **rich motion sketch** (layered beats + secondary life), not a flat poster that barely moves.

| Prefer | Avoid |
|--------|--------|
| Full-viewport stage (100vw×100vh) + Fullscreen API | Inset card + scrolling meta under the hero |
| Aspect-locked cover (16:9 default) filling the screen | Dashboard clutter, card grids in the hero |
| CSS/`@keyframes` one-shot until end, paused until `Space` | Autoplay, `infinite` / looping shot timelines, Space restart |
| Layered camera + light + subject + micro-UI + atmosphere | Single fade-in with nothing else moving |
| Staggered reveals, easing, hold on end frame | Everything popping at t=0 then freezing |
| Prompt / research in toggle overlay (`I` / `?`) | Fake photoreal video, watermarked stock embeds |
| Expressive fonts when they serve mood | Default system-only stacks for cinematic shots |

**Sync with VO meaning:** if narration teaches a step or names a UI, show that metaphor on stage (even abstractly). Mood-only VO → prioritize prompt cinematography.

**Language:** **Prefer English** for all on-stage chrome, labels, badges, chat bubbles, code comments, and hint text. Do not default to Chinese even when Chinese VO is present. **Never** put spoken narration / VO lines on the stage. Keep the **original prompt + VO text** (Chinese and English) only in the toggle overlay. Overlay headings and research notes should also be English.

**Typography / readable stage text (required):**

Stage labels are viewed fullscreen — **do not ship micro-UI**. Anything the viewer should parse (chrome titles, badges, graph nodes, file cards, status chips, code lines, gate names) must stay large enough at 16:9 cover.

| Element | Minimum size guidance |
|---------|----------------------|
| Primary labels (badges, thesis chips, CTA, key nodes) | `clamp(14px, 1.8vw, 20px)` or larger |
| Secondary UI (window chrome, folder/file names, status) | `clamp(13px, 1.5vw, 17px)` |
| Micro ornament only (optional ticks, tiny meters) | may go smaller — but **never** put critical meaning there |
| Hint bar (`.fs-hint`) | ≥14–15px |

- Prefer fewer, larger labels over dense 8–10px walls.
- When enlarging type, also bump padding / card height so text is not cramped.
- Anti-pattern: `font-size: 7px`–`11px` clamps on graph nodes, code, or badges “to fit more” — cut content instead.

### 4a. Animation richness (required)

Ship a **dense but readable** stage. Thin “one transform + one opacity” demos are not enough.

**Motion budget (minimum):**

| Layer | Role | Examples |
|-------|------|----------|
| 1. Camera | Energy **only if** the shot’s Camera line calls for it; otherwise lock or micro-parallax | Push-in / pull-back / pan / dutch / orbital **when Camera says so**; locked multilayer HUD when it doesn’t |
| 2. Primary subject | What the shot is about | Prototype appearing, module docking, graph exploding, gate locking, **code lines revealing** |
| 3. Secondary / support | Proof the world is alive | Sibling UI panels, folder tree growth, packet lanes, platform pieces |
| 4. Light & atmosphere | Mood continuity from Visual Style | Lamp pulse, monitor bloom, volumetric haze drift, vignette breathe, rim-light shift |
| 5. Micro-detail | Texture without stealing focus | Cursor blink, scrubber/knob, floating code bits, dust/particles, soft shadow crawl |

Require **at least 4 of these 5 layers** on every shot, and **≥5 independently timed animated elements or beats** after `Space` (e.g. code-line stagger + tree growth + platform docking + clock scrub + play-view bloom — **not** five CSS properties on one element). Ambient loops (`infinite` lamp flicker, dust) are OK **only if subtle**, non-narrative, and do **not** read as the shot replaying; the **main narrative beat stays one-shot + forwards**.

**Camera vs readable content (priority):**

When the stage shows **important content** — real project code / API call sites, terminal output, labeled architecture, readable UI chrome the viewer must parse — **prefer readability over cinematic camera**:

1. **Do not** default to whole-frame push-in / zoom / orbit on `.scene` just to “have a Camera layer.”
2. Prefer **locked camera** (or tiny parallax / drift that does not shrink text) **or** a **local emphasis** on the important block (scale/highlight that one panel or code card — not the entire stage).
3. Whole-frame camera moves are allowed only when the shot’s **Camera** line explicitly asks (push-in, pull-back, orbital, tracking, etc.) **and** they won’t make the key text/code illegible.
4. If Camera is composite / multilayer / locked-off (“parallel HUD”, “static board”, …), treat Camera as **depth + panel energy**, not zoom.

**Depth & layering:**

- Build **≥3 depth planes** (bg / mid / fg or room / screens / desk props). Parallax them slightly **when** there is a camera move (different translate amounts — avoid scale that eats readability).
- Prefer real structure (monitor bezels, desk, lamp, HUD chrome) over a single flat rectangle with text.
- Use soft masks, inset bezels, bloom, and gradient haze so the frame doesn’t look like clipped divs on black.

**Timing craft (map to Duration):**

1. **Idle (pre-Space):** readable establishing frame — lights on, subjects in start pose, no story progress.
2. **Setup (first ~20–30%):** environment wakes — UI populates, secondary elements stagger in (`animation-delay` cascade).
3. **Development (middle):** primary transformation from the video prompt (build / collapse / reveal / dock).
4. **Accent (~last 20%):** punch the Camera/VO payoff (RUN success, shockwave, CTA hold, badge snap).
5. **Hold:** freeze the end pose (`forwards`); no rewind.

Use **staggers** (40–120ms steps) for lists, folders, packets, checkmarks. Prefer `cubic-bezier` / ease-out on arrivals; reserve snappy ease for hits and smash cuts. If Duration is `~8s`, keep the CSS timeline ≈8s — don’t compress a whole story into 2s then dead-air.

**Detail recipes (pick what fits the prompt):**

| Shot type | Enrich with |
|-----------|-------------|
| Desk / editor / IDE | Dual screens, sidebar tree stagger, typed/fading code lines, blinking caret, playview empty→alive, clock or timeline scrub, warm lamp + cool monitor mix; **keep code readable** — local emphasis on the editor, not whole-frame zoom |
| Architecture / graph | Nodes lighting in sequence, edges drawing, local cyan vs global fog, camera pull-back revealing scale, soft particle drift |
| Chaos / debt | Multiplying clones, spaghetti cables growing, amber warning pulses, dutch tilt increasing, denser particle rain — still graphic-clean, not illegible spam |
| Product / module dock | Orbital turntable, modules easing into sockets with short “dock” scale settle, rim light pass, label fades (short, abstract) |
| Pipeline / steps | Lateral track or stepped gates lighting cyan as a token passes; each gate a micro-animation, not one long slide |
| Game-feel montage | Meter needles, multi-hit sparks, toast slide+fade, one-shot VFX sheet burst — cut accents on beats, no seizure strobe |

**CSS/JS practical rules:**

- Gate story animations behind `.is-playing` (or equivalent). Idle may use only tiny ambient loops.
- Prefer `transform` + `opacity` (+ `filter` sparingly) for performance; avoid layout thrash.
- Name keyframes by intent (`cameraPush`, `platformGrow`, `badgeIn`) so timing stays editable.
- Optional tiny JS for clocks, counters, or step indices — keep logic short; CSS owns most motion.
- **No** on-stage VO captions, karaoke, or subtitle bars.

**Anti-patterns (reject before shipping):**

- Only opacity fade on the whole stage
- Static screenshot look after play starts
- All elements sharing one identical delay/duration
- Busy infinite loops that feel like a GIF restart
- Unreadable micro-text walls or fake brand logos
- Stage chrome / nodes / badges at ~7–11px (too small for fullscreen; enlarge or drop labels)
- Burning narration into the frame
- Default whole-frame `scale` / push-in while code or other critical text is on stage (zooms away readability)
- Inventing camera moves not present in the shot’s **Camera** line

### 4b. Pre-flight motion checklist

Before writing the file, briefly plan (internally or in overlay research notes):

1. Camera from the shot’s **Camera** line — if important code/content is on stage, choose **lock / local zoom on that content**, not whole-frame push  
2. Primary beat from the **Video prompt**  
3. Two secondary enrichments (UI / props / particles)  
4. Light or atmosphere continuity from **Visual Style**  
5. End-frame hold that matches the payoff  

If any item is missing, add it before coding.

### 5. Suggested HTML skeleton

Adapt freely; keep **fullscreen** structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>[Shot title] · preview</title>
  <style>
    html, body { height: 100%; margin: 0; overflow: hidden; background: #000; }
    .stage {
      position: fixed; inset: 0; width: 100vw; height: 100vh;
      /* Full viewport host; .frame uses 16:9 cover by default. */
    }
    .frame {
      position: absolute; left: 50%; top: 50%;
      width: max(100vw, 177.78vh); /* 16:9 cover */
      height: max(100vh, 56.25vw);
      transform: translate(-50%, -50%);
      overflow: hidden;
    }
    .hud { position: fixed; /* hint + overlay; hidden by default */ }
  </style>
</head>
<body>
  <div class="stage" id="stage">
    <div class="frame"><!-- scene layers only — no VO caption --></div>
  </div>
  <div class="fs-hint">Space to play · Click / F fullscreen · I prompt</div>
  <aside class="overlay" hidden><!-- title, prompt, research — toggle with I / ? --></aside>
  <script>
    // Space adds .is-playing once; keyframes use forwards; no loop / no Space restart
    // click/F → requestFullscreen; I → overlay
  </script>
</body>
</html>
```

## Multi-shot (optional)

Only if the user asks for a full board:

- One HTML with shot tabs **or** sequential stages timed to each `Duration`
- Still one file unless they request a folder of per-shot previews
- Research once per distinct domain concept (don’t repeat identical searches)

## Quality bar

- [ ] HTML file written to disk; browser opened (or clear open instructions)
- [ ] **Fullscreen:** stage fills viewport; Fullscreen API on click/`F`; no scrolling meta under the frame
- [ ] **Space to play:** main timeline paused on load; `Space` starts once; no story autoplay; optional pre-play ambience is subtle and non-narrative; no on-stage VO text
- [ ] **Play once:** no loop; end frame held; no auto-replay / Space restart after finish
- [ ] Stage matches prompt subject, camera energy, and aspect
- [ ] Concepts extracted from VO, or from the video prompt when VO is absent; factual/usage gaps researched when needed
- [ ] **Rich motion:** ≥4 of 5 layers (camera / primary / secondary / light / micro); ≥5 independently timed elements or beats; ≥3 depth planes
- [ ] **Readable priority:** important code/content → locked camera or local emphasis; no default whole-frame zoom that shrinks text
- [ ] **Typography:** on-stage labels use large clamps (primary ≥~14–20px, secondary ≥~13–17px); no critical 7–11px micro-text
- [ ] Timing follows Duration (setup → development → accent → hold); staggers on lists/UI; not one global fade
- [ ] Visible continuous life after play starts (not a still poster); ambient loops stay subtle
- [ ] Self-contained; no storyboard overwrite; no video API calls
- [ ] Chat stays short: path + shot + research takeaway

## CLI

Copy-paste commands: [cli/storyboard-shot-to-html.md](../../../cli/storyboard-shot-to-html.md)
