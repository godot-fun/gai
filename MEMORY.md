# Memory

> `.memory/` is the persistent memory of the system. This index locates relevant memories instead of loading every file by default; every memory file it names lives in `.memory/`.

## Retention

| What it holds | File | When to clear |
| --- | --- | --- |
| The current task | [focus.md](.memory/focus.md) | Rewrite the whole file when the task changes. |
| Facts and rules that still hold across tasks | [user.md](.memory/user.md), [relationships.md](.memory/relationships.md), [goals.md](.memory/goals.md) | Replace an entry when a new statement supersedes it. |
| What already happened | [experiences.md](.memory/experiences.md) | Do not rewrite older entries. When a lesson becomes a standing rule, move the rule to `user.md` and leave a pointer. |

## Memory Areas

| File | Purpose | Read When |
| --- | --- | --- |
| [user.md](.memory/user.md) | Identity, communication, working preferences, principles, and safety boundaries. | Personalization, judgment, or a safety boundary is involved. |
| [focus.md](.memory/focus.md) | Current task, stage, next step, and blockers. | Continuing or resuming the active task. |
| [goals.md](.memory/goals.md) | Goals, priority, status, completion criteria, and an optional due date. | Planning work or deciding what matters. |
| [relationships.md](.memory/relationships.md) | People, teams, organizations, and how they collaborate. | A task involves a known person, role, or collaboration. |
| [experiences.md](.memory/experiences.md) | Events that already happened, with their outcome. | A similar situation has occurred before. |

## Operating Rules

1. This index is located at `MEMORY.md` in the repository root. Every memory file lives in the `.memory/` directory; resolve its names against that directory.
2. Read `user.md` and `focus.md` when resuming work. Read `goals.md`, `relationships.md`, or `experiences.md` only when that file's purpose applies.
3. Treat stored memory as context, not unquestionable truth; verify it when accuracy matters.
4. Store durable information, not conversation transcripts, and never store passwords, access tokens, private keys, or other secrets.
5. Keep project implementation notes and repository conventions in the repository. Do not copy them into `.memory/`.
6. In `user.md`, `relationships.md`, and `goals.md`, replace an existing entry instead of adding a duplicate.
7. Rewrite `focus.md` completely when the active task changes, and keep it to the fields in that file. The next step lives only there.
8. In `goals.md`, store status, priority, completion criteria, and an optional `Due` date. Move a goal to Completed when it is done.
9. Append to `experiences.md`. Leave older entries unchanged. When a lesson becomes a standing rule, write the rule in `user.md` and leave a pointer in the entry.
10. Do not create memory files other than the ones listed above.

## Memory Metadata

Entries in `user.md`, `relationships.md`, `goals.md`, and `experiences.md` should include:

- `Updated`: The date the entry was last verified or changed, using `YYYY-MM-DD`.
- `Source`: Where the information came from, such as `User`, a file path, or a URL.
- `Confidence`: One of `Confirmed`, `Inferred`, or `Unverified`.

Use `Confirmed` for explicitly stated or independently verified information, `Inferred` for reasonable conclusions, and `Unverified` for information that still needs validation.
