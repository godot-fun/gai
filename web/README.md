# gai-web-server

Always run through `.dependency/node/npm.cmd` so the repo Node is used (not a host install).

Install (dependencies + Chromium via `postinstall`):

```bash
.dependency/node/npm.cmd install --prefix web
```

Start:

```bash
.dependency/node/npm.cmd start --prefix web
```

Test (start the server first; the `/fetch`, `/search`, and `/healthy` tests call it):

```bash
.dependency/node/npm.cmd run test --prefix web
```

Typecheck:

```bash
.dependency/node/npm.cmd run typecheck --prefix web
```

## MCP

Copy `web/mcp.example.json` to `web/mcp.json` and configure one or more stdio or Streamable HTTP servers. The agent discovers them through `GET /mcp/tools` and calls them through `POST /mcp/call`. Without `mcp.json`, MCP is simply disabled. Set `MCP_CONFIG_PATH` to load the configuration from another location.
