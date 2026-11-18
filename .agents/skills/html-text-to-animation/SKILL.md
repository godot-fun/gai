---
name: html-text-to-animation
description: Turn text, scripts, concepts, or narration into polished self-contained HTML animations by selecting and adapting a visual style from the bundled reference library. Use when Codex needs to create an animated HTML page, motion-graphics scene, kinetic-typography piece, animated explainer, title sequence, data story, or browser-based visual narrative from written material.
---

# HTML Text to Animation

Create a self-contained HTML animation from user-supplied text. Select a style deliberately, adapt it to the subject, and implement the result without copying a reference as a rigid template.

## Workflow

1. Read the user's source text and identify its purpose, emotional arc, audience, desired duration, aspect ratio, and delivery context.
2. Read [catalog.md](catalog.md). Choose one primary style, or at most two compatible styles when a hybrid materially improves the result.
3. All style files are stored in `references/`. Search that directory for the selected style's exact name and read only the matching file. Preserve its `Signature Features`, respect its `Avoid` boundaries, and adapt everything else to the user's material.
4. Convert the source into a concise beat sheet before coding. Give every beat one dominant visual idea and ensure the opening has meaningful motion within 0.5 seconds.
5. Build one complete, self-contained HTML file unless the user asks for another structure. Prefer native HTML, CSS, SVG, and Canvas. Choose the rendering method that best serves the design; do not reproduce historical sample code.
6. Preserve user-provided wording exactly unless rewriting or translation is requested. Never invent quotations, statistics, attribution, or factual claims.
7. Verify the animation in a browser. Check layout, timing, text readability, responsive scaling, and console errors.

Do not copy sample brands, characters, wording, or hard-coded layouts from reference material.

## Style Selection

- Match meaning before appearance. Use an editorial or data style for evidence-heavy text, expressive typography for emotional copy, and diagrammatic styles for explanations.
- Prefer one coherent visual grammar over a collage of unrelated effects.
- When a candidate belongs to a similar-style family, compare the choice boundary in its `Overview` and the named alternatives in `Avoid`; select the style whose defining mechanism matches the material, not merely the nearest title.
- Do not combine styles merely to add variety. Combine them only when their composition, palette, and motion principles are compatible.
- When the user names a style, use that reference directly.
- When the request is open-ended, choose the style yourself: judge the material against the catalog and commit to the strongest single fit, then build it. Do not ask which style to use, do not hand the user a menu of candidates, and do not wait for approval.

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
- Keep labels, legends, and body text outside high-frequency detail and intense highlights.
- Do not replace the selected style's defining mechanism with a generic glow, particle field, slideshow, or surface effect.
- Keep implementation choices flexible. The references define visual behavior, not a required JavaScript architecture.

## Reference Format

Every style reference uses the same sections:

- `Overview`: identity and appropriate use.
- `Metadata`: exactly `Collection`, `Medium`, and `Best for`, in that order.
- `Signature Features`: required characteristics.
- `Style Prompt`: reusable English direction covering composition, palette, material behavior, motion, and camera.
- `Avoid`: failure modes and incompatible choices.

Treat `Signature Features` and `Avoid` as the style boundary. Adapt subject, wording, duration, aspect ratio, palette emphasis, pacing, scene content, and implementation method when the user has not fixed them.
