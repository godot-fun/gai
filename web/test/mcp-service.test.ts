import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { McpService } from "../src/services/mcp-service";

test("McpService accepts an empty server configuration", async () => {
  const directory = await mkdtemp(join(tmpdir(), "gai-mcp-"));
  const configPath = join(directory, "mcp.json");
  const previousPath = process.env.MCP_CONFIG_PATH;
  try {
    await writeFile(configPath, JSON.stringify({ servers: {} }));
    process.env.MCP_CONFIG_PATH = configPath;
    const service = new McpService();
    assert.deepEqual(await service.listTools(), []);
    await service.close();
  } finally {
    if (previousPath === undefined) delete process.env.MCP_CONFIG_PATH;
    else process.env.MCP_CONFIG_PATH = previousPath;
    await rm(directory, { recursive: true, force: true });
  }
});
