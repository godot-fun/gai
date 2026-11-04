---
name: experiences
description: Records events that already happened, with their outcome. Read when a similar situation has occurred before. Append a new entry; do not rewrite older entries. When a lesson becomes a standing rule, move that rule to user.md and leave a pointer here.
---

# Experiences

> What already happened. Append a new entry and leave older entries unchanged. Do not store conversation transcripts. When a lesson becomes a standing rule, write the rule in `user.md` and leave only a pointer in the entry.

## 2026-11-02: Visual unit test suite segfaults at shutdown

- Context: Headless run of `agent/test/visual/unit/VisualUnitTest.tscn`.
- What happened: Assertions passed, then Godot exited 139 during teardown. The same exit code existed at commit `86ac4cfb`. GeometricGenesis and InkLandscape also report FAIL when an earlier test in the folder logs an error, because `UnitTest.gd` fails the remaining tests after the first error.
- Outcome: Exit 139 on this suite is a teardown segfault, so it does not by itself show that the change under test caused a regression.
- Related files: `agent/test/visual/unit/VisualUnitTest.tscn`
- Updated: 2026-11-02
- Source: repeated headless runs of VisualUnitTest.tscn and HEAD~1 copies
- Confidence: Confirmed

<!-- Example:
## YYYY-MM-DD: Event Name

- Context:
- What happened:
- Outcome:
- Related files:
- Rule: user.md#Principles
- Updated: YYYY-MM-DD
- Source: User / file path / URL
- Confidence: Confirmed / Inferred / Unverified
-->
