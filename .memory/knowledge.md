---
name: knowledge
description: Records verified facts, concepts, and project knowledge worth reusing over time. Read before answering factual questions or performing related tasks; update when reliable and reusable knowledge is discovered.
---

# Knowledge

> Records verified facts and knowledge worth reusing over time. Do not store unverified assumptions.

## Project Knowledge

### Transformer visuals tokenize offline when llama-server is down
- Knowledge: `TransformerController.tokenize_text` probes the llama-server only when `VLMServer.is_running()` (avoids one HTTP transport error log per animation) and otherwise falls back to `LocalTokenizer.tokenize` (`agent/server/LocalTokenizer.gd`). The fallback is heuristic, not the real Qwen2 BPE: CJK per character, latin/digit runs as words (runs > 8 chars split into 4-char pieces), punctuation alone, `▁` word-boundary marker, FNV-1a IDs inside `VOCAB_SIZE` 151936, max 128 tokens.
- Updated: 2026-11-02
- Source: agent/server/LocalTokenizer.gd, agent/ui/visuals/transformer/TransformerController.gd
- Confidence: Confirmed

### Skill index lives in the manager layer and self-refreshes by disk fingerprint
- Knowledge: `SkillManager` (`agent/manager/skill/SkillManager.gd`) owns `.agents/skills` discovery, `SKILL.md` front-matter parsing, and description trimming. Entries are typed `SkillSummary` objects (`name` + `description`; explicitly a summary, not the skill body or path), never bare `Dictionary`. `get_summaries()` rescans when the disk fingerprint changed: `build_signature(folders)` is folder names + each `SKILL.md` mtime, joined with a `StringBuilder`, so a skill added/renamed/edited while the app runs appears on the next `/` completion with no watcher and no restart. Godot reports mtime in whole seconds, so two edits inside one second may only be noticed by a later change. `ChatInputSkillCompletion` (`agent/ui/input/`) keeps only CodeEdit popup behavior plus static `matching_summaries(summaries, token)` / `build_display_text(summary)` helpers. `SkillPrompt` intentionally keeps its own static README snapshot, because `is_skill_context_message` compares existing session messages against that exact text — the model-facing skill index still only refreshes on restart or new-session injection.
- Updated: 2026-11-02
- Source: agent/manager/skill/SkillManager.gd, agent/ui/input/ChatInputSkillCompletion.gd, agent/test/manager/SkillManagerTest.gd
- Confidence: Confirmed

### Visual unit test suite segfaults at shutdown
- Knowledge: `agent/test/visual/unit/VisualUnitTest.tscn` passes its assertions in headless mode but Godot exits 139 (segfault during teardown); the same behavior exists at commit 86ac4cfb, so it is unrelated to any single test change. Some visual tests (GeometricGenesis / InkLandscape) also report FAIL when an earlier test in the folder logs an error, because `UnitTest.gd` fails the remaining tests after the first error.
- Updated: 2026-11-02
- Source: repeated headless runs of VisualUnitTest.tscn and HEAD~1 copies
- Confidence: Confirmed


## General Knowledge

<!-- Use the same Updated / Source / Confidence fields for each entry. -->

## To Verify

<!-- Entries in this section should normally use Confidence: Unverified. -->
