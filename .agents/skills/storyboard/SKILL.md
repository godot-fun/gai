---
name: storyboard
description: >-
  Turns user materials into a shot-by-shot storyboard with bilingual narration
  (Chinese + English VO by default; honor explicit single-language requests) and AI video prompts per shot. When the
  user gives a target path (especially .md), write the full storyboard there —
  do not only print it in chat. Style and duration are free. Use when the user
  asks for storyboard, shot list, narration, VO script, AI video prompts,
  image-to-video prompts, or a video plan from images/clips/copy.
---

# Storyboard

From **user materials only**, produce:

1. **Narration** per shot — **Chinese and English** (both required unless user opts out)
2. **Video prompt** per shot — ready for i2v / t2v

Do not invent product facts, prices, logos, or claims not in the materials.
Style and length are agent-chosen from the content (no fixed genre or duration).

## Inputs

Any mix of stills, clips, text brief, and constraints. Optional: a delivery file path.

If goal/audience is ambiguous, state one short assumption and proceed. Ask only when a missing fact would make the storyboard unusable.

## Delivery

| Mode | Behavior |
|------|----------|
| User gives a file path | Write the **full** storyboard markdown to that path. Chat: short confirm (path, runtime, shot count) only |
| No path | Full storyboard in chat |

Treat a path as the **output file** when:

1. User says write to / save as / put in + path
2. It is an empty or draft `.md` / `.txt` file clearly intended for this output
3. The user identifies it as the storyboard document, not merely as source material

**Rules:**

- Always **read** the target file first if it exists. Replace a non-empty file only when it is clearly the requested output/draft; preserve its useful facts in `## Materials` / Spine.
- Treat an existing non-empty document presented as a brief, script, transcript, or reference as **input**, not an overwrite target. If no output path is given, deliver in chat.
- One doc + images → write to the doc; images are materials only.
- Explicit output path + separate brief → write only to the output path.
- Several docs, unclear target → do not guess which file to overwrite; ask once or deliver in chat when no file output was requested.
- User names a directory only → create `storyboard.md` there.

## Workflow

1. Detect delivery target (file vs chat)
2. Inventory materials (read delivery file if present)
3. Infer Visual Style (once for the whole piece)
4. Design story spine (hook → develop → payoff / CTA)
5. Break into shots (one clear idea each; duration free) — **Shot 01 is the eyeball grab** (see Shot 01)
6. Write bilingual VO + video prompt per shot
7. Write Assembly (after Spine), then Shots
8. Consistency pass; deliver in required format

### Visual Style (once)

Medium, mood, color/light, camera language, motion energy, aspect (default **16:9**). Keep consistent across prompts unless a deliberate style shift is story.

### Spine patterns

- Product → desire/problem → reveal → benefit → close
- Character → setup → turn → resolution
- Trailer → hooks and escalating beats
- Explain → claim → show → reinforce
- Attention-scarce / fragmented viewing → **grab in Shot 01** → develop → payoff / CTA

Spine may note what Shot 01 uses to stop the scroll; that hook is **not** a summary of the whole piece.

### Shot rules

- One idea per shot; prefer a **visible cause of motion**
- Reference still present → **i2v** (motion relative to that frame)
- No frame → **t2v** (full self-contained scene)
- Respect user aspect; default 16:9
- No invented logo text, legal claims, or competitor names

### Shot 01 (hook — grab attention)

Attention is fragmented: **Shot 01 must catch the eye**. It is an opening line that stops the scroll—not a summary of the video, and not necessarily the piece’s main thesis.

- Prefer a sharp cold open: tension, curiosity, contrast, surprise, or a vivid concrete moment
- VO + picture work as a hook; soft mood builds, empty atmosphere, or early detail dumps fail here
- The main argument / product reveal can land in later shots; Shot 01 only needs to pull the viewer in
- If materials already give a hook line, keep it and amplify — do not invent facts

### Narration (bilingual default)

| Field | Use |
|-------|-----|
| **Chinese** | Spoken Chinese for TTS / record (or `(no VO)`) |
| **English** | Spoken English for TTS / record (or `(no VO)`) |

- Same idea in both languages (natural spoken, not word-for-word).
- Length vs duration: Chinese ~3–4 chars/sec; English ~2–3 words/sec. Tighten the side that overruns.
- **Sync on edit:** if either VO changes, update the other VO and related fields (`Duration`, `Visual`, `Camera`, `Video prompt`) in the same edit.
- User gives one language verbatim → keep it; write a natural equivalent for the other.
- User asks for only one language → omit the other field.

### Video prompts

Self-contained for a generic model. Include: subject + action in time order, camera (frame + move), environment, light/color, motion intensity, continuity anchors.

- i2v: start with `Image-to-video from provided still: …` then motion (+ keep composition unless changing)
- t2v: full scene + Visual Style cues
- Prefer concrete verbs; avoid named living artists / unlicensed IP not in materials
- Optional: `Avoid: flicker, morphing faces, extra limbs, watermark, text overlay`
- **English** prompt body unless user requires Chinese

## Output format (required)

Section order is fixed: Materials → Visual Style → Spine → Assembly → Shots.

```markdown
# Storyboard — [working title]

## Materials
- [asset or note → role]

## Visual Style
- Medium:
- Mood:
- Color / light:
- Camera:
- Motion energy:
- Aspect: [e.g. 16:9]

## Spine
[1–4 sentences: arc + rough total runtime]

## Assembly
[shot order, total runtime, TTS/BGM/stitch notes if obvious]

## Shots

### Shot 01 — [short title — cold open / hook]
- **Duration:** ~Xs
- **Source:** [file / t2v / i2v from …]
- **Visual:** [composition]
- **Camera:** [framing + move]
- **Chinese:** [spoken Chinese, or (no VO)]
- **English:** [spoken English, or (no VO)]
- **Video prompt:**
  ```
  [full prompt — English preferred]
  ```
- **Avoid (optional):** …

### Shot 02 — …
…
```

## Quality bar

- [ ] File path given → full markdown **saved there** (UTF-8); not chat-only
- [ ] Section order: Materials → Visual Style → Spine → Assembly → Shots; every shot has Chinese + English + Video prompt unless the user opted out of one VO language
- [ ] VO languages sense-aligned; durations match speak length
- [ ] **Shot 01** grabs attention as a cold open (not a thesis summary; no slow-burn open)
- [ ] Facts trace to materials; style coherent; i2v points at the right still
- [ ] No video/image generation APIs unless user separately asks
- [ ] No invented output path when user gave none → chat delivery only

## CLI

Copy-paste commands: [cli/storyboard.md](../../../cli/storyboard.md)
