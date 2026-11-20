---
name: storyboard
description: >-
  Generates narration or voice-over lines from user-provided materials, with
  all Chinese lines first and all English lines second by default. Use when the
  user asks for narration, dialogue, a VO script, spoken copy, or lines for a
  video. Honor explicit single-language requests and write the full script to
  a requested output file.
---

# Narration Script

Generate spoken lines only. Do not add visuals, camera directions, video
prompts, editing notes, music cues, or a storyboard unless the user explicitly
requests them.

## Content

- Use only facts supported by the user's materials. Do not invent product
  facts, prices, logos, claims, or quotations.
- Write natural spoken language rather than literal translation.
- Keep the Chinese and English versions meaning-aligned, but let each sound
  native in its own language.
- Preserve user-provided wording when the user asks to keep it verbatim.
- Infer a reasonable tone and length from the materials. State one short
  assumption only when it materially affects the result.
- If the user requests one language, output only that language section.

## Language order

For bilingual output:

1. Write the complete Chinese section.
2. Then write the complete English section.
3. Never alternate Chinese and English line by line.
4. Use matching numeric IDs so corresponding lines remain easy to pair.
5. The two languages may use different sentence boundaries; keep the IDs
   aligned by meaning.

## Delivery

- If the user explicitly gives an output file, read it first and write the full
  script there as UTF-8. Replace it only when it is clearly an output or draft.
- Treat briefs, scripts, transcripts, and reference documents as input unless
  the user explicitly asks to overwrite them.
- If the user explicitly gives an output directory, create
  `narration-script.md` in it.
- If no output destination is requested, return the full script in chat.

## Output format

```markdown
# Narration Script — [title]

## Chinese

### 01
[完整中文台词]

### 02
[完整中文台词]

## English

### 01
[Complete English narration]

### 02
[Complete English narration]
```

Optional short labels may follow an ID, for example `### 01 — Opening`.
Do not add empty language sections.

## Check

- The output contains spoken lines only.
- All Chinese lines appear before the English section.
- IDs are unique, ordered, and meaning-aligned across languages.
- The wording is natural when read aloud.
- Every factual statement traces to the supplied materials.
- A requested output path received the full script.
