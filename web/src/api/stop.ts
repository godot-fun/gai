import { IncomingMessage, ServerResponse } from "node:http";
import { sendOk } from "../http";
import { browserService } from "../services/browser-service";
import { mcpService } from "../services/mcp-service";
import { shutdown } from "../shutdown";
import { registerApi, ApiRoute } from "./route";

// The caller force-kills this process right after the reply, so never let cleanup block the reply.
const PRE_SHUTDOWN_TIMEOUT_MS = 5_000;

export class StopApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/stop";

  async handle(_request: IncomingMessage, response: ServerResponse): Promise<void> {
    // Release the browser and MCP child processes first; otherwise they outlive the killed server.
    try {
      await closeChildren();
    } catch (error) {
      console.error("Pre-shutdown cleanup failed", error);
    }
    sendOk(response, { status: "stopping" });
    response.once("finish", () => setTimeout(() => shutdown("/stop"), 100));
  }
}

async function closeChildren(): Promise<void> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      Promise.all([browserService.close(), mcpService.close()]),
      new Promise<void>((resolve) => { timer = setTimeout(resolve, PRE_SHUTDOWN_TIMEOUT_MS); }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

registerApi(new StopApi());
