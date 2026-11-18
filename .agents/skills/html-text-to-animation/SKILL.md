---
name: html-text-to-animation
description: Turn text, scripts, concepts, or narration into polished self-contained HTML animations by selecting and adapting a visual style from the bundled reference library. Use when Codex needs to create an animated HTML page, motion-graphics scene, kinetic-typography piece, animated explainer, title sequence, data story, or browser-based visual narrative from written material.
---

# HTML Text to Animation

Create a self-contained HTML animation from user-supplied text. Select a style deliberately, adapt it to the subject, and implement the result without copying a reference as a rigid template.

## Workflow

1. Read the user's source text and identify its purpose, emotional arc, audience, desired duration, aspect ratio, and delivery context.
2. Read [references/catalog.md](references/catalog.md). Choose one primary style, or at most two compatible styles when a hybrid materially improves the result.
3. Read only the selected style reference files. Treat `Signature Features` as invariants and `Customizable Elements` as creative freedom.
4. Convert the source into a concise beat sheet before coding. Give every beat one dominant visual idea and ensure the opening has meaningful motion within 0.5 seconds.
5. Build one complete, self-contained HTML file unless the user asks for another structure. Prefer native HTML, CSS, SVG, and Canvas. Choose the rendering method that best serves the design; do not reproduce historical sample code.
6. Preserve user-provided wording exactly unless rewriting or translation is requested. Never invent quotations, statistics, attribution, or factual claims.
7. Verify the animation in a browser. Check layout, timing, text readability, responsive scaling, and console errors.

## Style Selection

- Match meaning before appearance. Use an editorial or data style for evidence-heavy text, expressive typography for emotional copy, and diagrammatic styles for explanations.
- Prefer one coherent visual grammar over a collage of unrelated effects.
- When a candidate belongs to a similar-style family, compare the choice boundary in its `Overview` and the named alternatives in `Avoid`; select the style whose defining mechanism matches the material, not merely the nearest title.
- Do not combine styles merely to add variety. Combine them only when their composition, palette, and motion principles are compatible.
- When the user names a style, use that reference directly. When the request is open-ended, select two or three candidates from the catalog, decide internally, and proceed with the strongest fit.

## Animation Principles

- Make animation communicate structure, causality, emphasis, or emotion. Avoid decorative motion with no narrative purpose.
- Establish a clear hierarchy among headline, supporting text, visual subject, and background detail.
- Keep each text block on screen long enough to read. Split dense text into beats instead of shrinking it.
- Base the scene on elapsed time so playback remains stable across refresh rates.
- Use deterministic variation when random-looking marks, particles, grain, or jitter must reproduce consistently.
- Respect `prefers-reduced-motion` by providing a readable reduced-motion state.
- Avoid external dependencies unless they substantially improve the requested result or the user explicitly permits them.

## Output Quality

- Return complete implementation rather than pseudocode or omitted sections.
- Use responsive scaling while preserving the intended composition and aspect ratio.
- Avoid horizontal overflow, clipped text, unreadable contrast, accidental scrollbars, and animation that begins before fonts or layout are ready.
- Keep implementation choices flexible. The references define visual behavior, not a required JavaScript architecture.

## Reference Format

Every style reference uses the same sections:

- `Overview`: identity and appropriate use.
- `Metadata`: searchable classification.
- `Signature Features`: required characteristics.
- `Style Prompt`: reusable English direction covering composition, palette, material behavior, motion, and camera.
- `Customizable Elements`: safe areas for invention.
- `Avoid`: failure modes and incompatible choices.
