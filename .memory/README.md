# Memory

> This directory is the persistent memory of the system. Use this index to locate relevant memories instead of loading every file by default.

## Memory Areas

| File | Purpose | Read When |
| --- | --- | --- |
| [profile.md](profile.md) | Identity, responsibilities, background, and communication traits. | Identity context or personalization is needed. |
| [relationships.md](relationships.md) | Important people, teams, organizations, and their relationships. | A task involves known people, roles, or collaboration. |
| [knowledge.md](knowledge.md) | Verified facts, concepts, and reusable project knowledge. | Factual or project context is required. |
| [goals.md](goals.md) | Long-term and current goals, priorities, status, and completion criteria. | Planning work or choosing the next action. |
| [focus.md](focus.md) | Current task context, focus, progress, next step, and blockers. | Continuing or resuming active work. |
| [experiences.md](experiences.md) | Significant events, outcomes, decisions, and lessons learned. | A similar situation has occurred before or history matters. |
| [principles.md](principles.md) | Values, working preferences, operating principles, and safety boundaries. | Making judgments, selecting an approach, or checking boundaries. |
| [reminders.md](reminders.md) | Dated, timed, and recurring reminders. | Checking schedules or scanning for due items. |

## Operating Rules

1. This index is located at `.memory/README.md`. Resolve every relative path in it against the `.memory/` directory.
2. Read only the memory files relevant to the current task.
3. Treat stored memory as context, not unquestionable truth; verify it when accuracy matters.
4. Store durable and reusable information, not complete conversation transcripts.
5. Update an existing entry instead of creating duplicates.
6. Distinguish confirmed facts from assumptions and items that still need verification.
7. Keep `focus.md` short and rewrite it as the active task changes.
8. Never store passwords, access tokens, private keys, or other secrets.
9. Preserve useful history when facts change; note the change in `experiences.md` when appropriate.

## Memory Metadata

Durable memory entries should include:

- `Updated`: The date the entry was last verified or changed, using `YYYY-MM-DD`.
- `Source`: Where the information came from, such as `User`, a file path, or a URL.
- `Confidence`: One of `Confirmed`, `Inferred`, or `Unverified`.

Use `Confirmed` for explicitly stated or independently verified information, `Inferred` for reasonable conclusions, and `Unverified` for information that still needs validation.

## Suggested Reading Order

1. Read `principles.md` when the task involves judgment, preferences, or safety.
2. Read `focus.md` to recover active task context.
3. Read one or more domain files from the table above as needed.
4. Check `reminders.md` only for scheduling or due-item workflows.
