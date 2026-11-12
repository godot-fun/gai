import { readFile } from "node:fs/promises";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { config } from "../config";

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
  private loading: Promise<void> | null = null;

  async listTools(): Promise<unknown[]> {
    await this.ensureConnected();
    return [...this.connections.entries()].flatMap(([server, connection]) => connection.tools.map((tool) => ({
      server,
      name: tool.name,
      qualifiedName: `mcp__${normalize(server)}__${normalize(tool.name)}`,
      description: tool.description ?? "",
      inputSchema: tool.inputSchema,
    })));
  }

  async callTool(server: string, name: string, args: Record<string, unknown>): Promise<unknown> {
    await this.ensureConnected();
    const connection = this.connections.get(server);
    if (connection === undefined) throw new Error(`Unknown MCP server: ${server}`);
    return connection.client.callTool({ name, arguments: args });
  }

  async close(): Promise<void> {
    this.loading = null;
    await Promise.allSettled([...this.connections.values()].map(({ client }) => client.close()));
    this.connections.clear();
  }

  /** Connects every configured server once; concurrent callers await the same attempt. */
  private ensureConnected(): Promise<void> {
    this.loading ??= this.connect().catch((error: unknown) => {
      this.loading = null; // Let a later request retry instead of caching the failure.
      throw error;
    });
    return this.loading;
  }

  private async connect(): Promise<void> {
    const path = config.mcpConfigPath;
    let mcpConfig: McpConfig;
    try {
      mcpConfig = JSON.parse(await readFile(path, "utf8")) as McpConfig;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
      throw error;
    }

    try {
      for (const [name, server] of Object.entries(mcpConfig.servers ?? {})) {
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
