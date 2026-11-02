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

### Visual unit test suite segfaults at shutdown
- Knowledge: `agent/test/visual/unit/VisualUnitTest.tscn` passes its assertions in headless mode but Godot exits 139 (segfault during teardown); the same behavior exists at commit 86ac4cfb, so it is unrelated to any single test change. Some visual tests (GeometricGenesis / InkLandscape) also report FAIL when an earlier test in the folder logs an error, because `UnitTest.gd` fails the remaining tests after the first error.
- Updated: 2026-11-02
- Source: repeated headless runs of VisualUnitTest.tscn and HEAD~1 copies
- Confidence: Confirmed


## General Knowledge

<!-- Use the same Updated / Source / Confidence fields for each entry. -->

## To Verify

<!-- Entries in this section should normally use Confidence: Unverified. -->
