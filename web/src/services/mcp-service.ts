import { readFile } from "node:fs/promises";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";

type McpServerConfig =
  | { transport: "stdio"; command: string; args?: string[]; cwd?: string; env?: Record<string, string> }
  | { transport: "http"; url: string; headers?: Record<string, string> };

interface McpConfig {
  servers?: Record<string, McpServerConfig>;
}

interface Connection {
  client: Client;
  tools: Awaited<ReturnType<Client["listTools"]>>["tools"];
}

export class McpService {
  private readonly connections = new Map<string, Connection>();
  private loaded = false;

  async listTools(): Promise<unknown[]> {
    await this.load();
    return [...this.connections.entries()].flatMap(([server, connection]) => connection.tools.map((tool) => ({
      server,
      name: tool.name,
      qualifiedName: `mcp__${normalize(server)}__${normalize(tool.name)}`,
      description: tool.description ?? "",
      inputSchema: tool.inputSchema,
    })));
  }

  async callTool(server: string, name: string, args: Record<string, unknown>): Promise<unknown> {
    await this.load();
    const connection = this.connections.get(server);
    if (connection === undefined) throw new Error(`Unknown MCP server: ${server}`);
    return connection.client.callTool({ name, arguments: args });
  }

  async close(): Promise<void> {
    await Promise.allSettled([...this.connections.values()].map(({ client }) => client.close()));
    this.connections.clear();
    this.loaded = false;
  }

  private async load(): Promise<void> {
    if (this.loaded) return;
    this.loaded = true;
    const path = process.env.MCP_CONFIG_PATH?.trim() || "mcp.json";
    let config: McpConfig;
    try {
      config = JSON.parse(await readFile(path, "utf8")) as McpConfig;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
      this.loaded = false;
      throw error;
    }

    try {
      for (const [name, server] of Object.entries(config.servers ?? {})) {
        const client = new Client({ name: "gai", version: "1.0.0" }, { versionNegotiation: { mode: "auto" } });
        const transport = server.transport === "stdio"
          ? new StdioClientTransport({ command: server.command, args: server.args, cwd: server.cwd, env: server.env })
          : new StreamableHTTPClientTransport(new URL(server.url), { requestInit: { headers: server.headers } });
        await client.connect(transport);
        const { tools } = await client.listTools();
        this.connections.set(name, { client, tools });
      }
    } catch (error) {
      await this.close();
      throw error;
    }
  }
}

function normalize(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_");
}

export const mcpService = new McpService();
