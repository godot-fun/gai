import { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, HttpStatus, readJsonBody, requireObject, requireString, sendOk } from "../http";
import { mcpService } from "../services/mcp-service";
import { registerApi, ApiRoute } from "./route";

class McpToolsApi implements ApiRoute {
  readonly method = "GET";
  readonly path = "/mcp/tools";

  async handle(_request: IncomingMessage, response: ServerResponse): Promise<void> {
    sendOk(response, { tools: await mcpService.listTools() });
  }
}

class McpCallApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/mcp/call";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const server = requireString(body.server, "server");
    const name = requireString(body.name, "name");
    const args = body.arguments === undefined ? {} : requireObject(body.arguments);
    try {
      sendOk(response, await mcpService.callTool(server, name, args));
    } catch (error) {
      throw new HttpError(HttpStatus.BAD_GATEWAY, "MCP_CALL_FAILED", error instanceof Error ? error.message : String(error));
    }
  }
}

registerApi(new McpToolsApi());
registerApi(new McpCallApi());
