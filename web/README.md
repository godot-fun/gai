# gai-web-server

Install:

```bash
.dependency/node/npm.cmd install --prefix web
```

Start:

```bash
.dependency/node/npm.cmd start --prefix web
```

Test (start the server first; the `/fetch`, `/search`, `/browser/action`, and `/healthy` tests call it):

```bash
.dependency/node/npm.cmd run test --prefix web
```

Typecheck:

```bash
.dependency/node/npm.cmd run typecheck --prefix web
```

Imports: a type-only import must say so (`import type { X } from ...`, or `import { value, type X } from ...`
when the statement also brings in values). The runtime is esbuild via `tsx`, which cannot tell types from
values, and `verbatimModuleSyntax` makes `typecheck` fail instead of letting it slip through.

## Browser control

`POST /browser/action` drives the shared Camoufox page the agent uses for browsing. The page lives
across requests, so login state, scroll position, and refs stay valid between calls until the
document navigates.

Request:

```json
{
  "steps": [{ "action": "click", "ref": "e3" }, { "action": "type", "ref": "e4", "text": "hello" }],
  "snapshot": true,
  "screenshotPath": "C:/tmp/page.webp"
}
```

- `steps` — 1 to 12 objects. `action` is one of `goto`, `snapshot`, `markdown`, `click`, `type`,
  `press`, `hover`, `select`, `scroll`, `back`, `forward`, `reload`. A step targeting an element
  takes `ref` (from the last snapshot) or a Playwright `selector`; `type` needs `text`, `press`
  needs `key`, `select` needs `value`, `goto` needs `url`. `markdown` fills `markdown` with the
  readable text of the live page (shared with `/fetch`; it sees login state and SPA navigation, which
  a fresh fetch would not). `press` sends keys to the page (`Enter`, `Escape`, `Tab`,
  `Control+A`, `ArrowDown`); history and reload are steps because synthetic keys never reach the
  browser chrome. There is no `wait` step — the snapshot is taken after the document settles.
- `snapshot` — return a fresh snapshot (default `true`).
- `screenshotPath` — optional absolute `.png`/`.jpg`/`.jpeg`/`.webp` path.

Reply: `{ ok, url, title, error, snapshot, markdown, screenshotPath, screenshotError }`.
A failed step answers `200` with `ok: false` and the message in `error`, plus a snapshot of the
page it failed on; only a malformed request is a `4xx`. `snapshot` groups the interactable elements of the
page under their landmark region:

```
- banner
  - link "Sign in" [e0]
- navigation "Global"
  - button "Products" (expanded=false) [e1]
- main
  - textbox "Email" value="me@example.com" [e2]
  - button "Submit" [e3]
```

Collection is deliberately unfiltered: every frame and every open shadow root is walked for elements
Playwright could interact with, and only then is the budget applied (300 elements, 180 links, two
copies of the same role+name, form controls before links). A partial view says so in a closing `text`
line — `(N interactive elements over the per-step budget, ...; N repeats collapsed ...; N nameless
elements skipped)` — instead of dropping elements silently.

`[eN]` is the handle to pass back as `ref`; a frame after the first prefixes it (`f2e12`). Refs are
stored in the page, so they go stale as soon as the document changes — the next call reports that
instead of clicking the wrong element.

## MCP

Copy `web/mcp.example.json` to `web/mcp.json` and configure one or more stdio or Streamable HTTP servers. The agent discovers them through `GET /mcp/tools` and calls them through `POST /mcp/call`. Without `mcp.json`, MCP is simply disabled. Set `MCP_CONFIG_PATH` to load the configuration from another location.
