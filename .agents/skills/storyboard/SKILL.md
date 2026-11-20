---
name: storyboard
description: >-
  Generates narration or voice-over lines from user-provided materials, with
  all Chinese lines first and all English lines second by default. Bilingual
  output is sentence-per-line, and line breaks pair one-to-one across
  languages. Use when the user asks for narration, dialogue, a VO script,
  spoken copy, or lines for a video. Honor explicit single-language requests
  and write the full script to a requested output file.
---

# Narration Script

Generate spoken lines only. Do not add visuals, camera directions, video
prompts, editing notes, music cues, or a storyboard unless the user explicitly
requests them.

## Content

- Use only facts supported by the user's materials. Do not invent facts, claims, or quotations.
- Write natural spoken language rather than literal translation. Keep the versions meaning-aligned, but let each sound native.
- Preserve user-provided wording when the user asks to keep it verbatim.
- Infer a reasonable tone and length from the materials. State one short assumption only when it materially affects the result.
- Put the estimated spoken duration in every segment heading.
- If the user requests one language, output only that language section.

## Language order

For bilingual output:

1. Write the complete Chinese section, then the complete English section. Never alternate Chinese and English line by line.
2. Use matching numeric IDs and the same estimated duration for matching IDs.
3. One line is one complete sentence. Never break a sentence across lines or join several sentences into one line.
4. Line breaks pair one-to-one: a segment has the same number of lines in every language, and line N says the same thing in each. If a clause deserves its own line, it gets its own line in every language.
5. No blank lines inside a segment; blank lines only separate segments.

## Delivery

- If the user explicitly gives an output file, read it first and write the full
  script there as UTF-8. Replace it only when it is clearly an output or draft.
- Treat briefs, scripts, transcripts, and reference documents as input unless
  the user explicitly asks to overwrite them.
- Use `storyboard.md` as the default output filename.
- If the user explicitly gives an output directory, create `storyboard.md` in it.
- If no output destination is requested, return the full script in chat.

## Output format

```markdown
# Narration Script — [title]

## Chinese

### 01 — 约 15 秒
[一句话]
[一句话]

### 02 — 约 20 秒
[一句话]

## English

### 01 — About 15 seconds
[One sentence]
[One sentence]

### 02 — About 20 seconds
[One sentence]
```

Segment `01` has two lines here, so both languages need two. Optional short
labels may follow the duration. Do not add empty language sections.

## Check

- The output contains spoken lines only.
- All Chinese lines appear before the English section.
- IDs are unique and ordered, with matching durations across languages.
- Each segment has the same number of lines in every language, paired by index.
- Every line is exactly one complete sentence, and no segment contains a blank line.
- The wording is natural when read aloud.
- Every factual statement traces to the supplied materials.
- A requested output path received the full script.

Count the lines per segment before delivering and fix any mismatch.
