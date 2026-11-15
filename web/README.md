# gai-web-server

Install:

```bash
.dependency/node/npm.cmd install --prefix web
```

Start:

```bash
.dependency/node/npm.cmd start --prefix web
```

Test (start the server first; integration tests call its HTTP endpoints):

```bash
.dependency/node/npm.cmd run test --prefix web
```

Typecheck:

```bash
.dependency/node/npm.cmd run typecheck --prefix web
```

Imports must mark types explicitly with `import type` or an inline `type` modifier. The runtime is
esbuild through `tsx`, and `verbatimModuleSyntax` makes TypeScript reject ambiguous imports.

## Browser control

The three browser endpoints share one long-lived Camoufox page, preserving login state and scroll
position. Navigation, observation, and mutation remain separate operations.

### Open

`POST /browser/open` navigates the shared page:

```json
{ "url": "https://example.com" }
```

It returns page metadata but does not observe the page. Call `/browser/observe` afterwards when
elements, readable text, or an image are needed.

### Observe

`POST /browser/observe` reads exactly one representation without changing the page:

```json
{ "mode": "elements" }
```

`mode` is `elements`, `markdown`, or `screenshot`. Screenshot mode also requires an absolute
`screenshotPath` ending in `.png`, `.jpg`, `.jpeg`, or `.webp`.

Elements are grouped under their landmark region and carry refs that actions can target:

```text
- banner
  - link "Sign in" [e0]
- main
  - textbox "Email" value="me@example.com" [e1]
  - button "Submit" [e2]
```

Collection walks every frame and open shadow root before applying the output budget. `[eN]` is a
main-frame handle; later frames use prefixes such as `[f2e12]`. Refs go stale when their document
changes, so observe elements again after navigation or a page-changing action.

### Action

`POST /browser/action` mutates the current page and always captures its final visual state:

```json
{
  "steps": [{ "action": "click", "ref": "e3" }],
  "screenshotPath": "C:/tmp/action.webp"
}
```

`steps` holds 1 to 12 entries. Supported actions are `click`, `type`, `press`, `hover`, `select`,
`scroll`, `back`, `forward`, and `reload`. Targeted actions take a ref from an elements observation
or a Playwright selector. `type` requires `text`, `press` requires `key`, and `select` requires
`value`. There is no wait step; page settling belongs to the session.

An action response contains metadata and screenshot fields, but no snapshot. A failed step answers
with HTTP 200 and `ok: false` so the caller receives its error and screenshot; malformed requests
use a 4xx response. Observe elements explicitly when new refs are needed.

All browser endpoints use the common response shape:

```text
{ ok, url, title, error, snapshot, markdown, screenshotPath, screenshotError }
```

Fields not produced by the selected operation are empty strings.

## MCP

Copy `web/mcp.example.json` to `web/mcp.json` and configure one or more stdio or Streamable HTTP
servers. The agent discovers them through `GET /mcp/tools` and calls them through `POST /mcp/call`.
Without `mcp.json`, MCP is disabled. Set `MCP_CONFIG_PATH` to load another configuration file.
