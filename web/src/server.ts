import { once } from "node:events";
import type { Server } from "node:http";
import { createApiServer } from "./api/index";
import { getApiRoutes } from "./api/route";
import { config } from "./config";
import { browserService } from "./services/browser-service";
import { mcpService } from "./services/mcp-service";
import { registerShutdownHandler, requestShutdown } from "./shutdown";

async function listen(server: Server): Promise<void> {
  server.listen(config.port, config.host);
  await once(server, "listening");
}

async function closeServer(server: Server): Promise<void> {
  await server[Symbol.asyncDispose]();
}

async function main(): Promise<void> {
  console.log("Starting CloakBrowser...");
  await browserService.start();
  const server = createApiServer();
  await listen(server);
  registerShutdownHandler(async () => {
    await Promise.all([closeServer(server), browserService.close(), mcpService.close()]);
  });
  console.log("Supported endpoints:");
  for (const route of getApiRoutes()) console.log(`  ${route.method.padEnd(5)}${route.path}`);
  console.log(`Web server listening at http://${config.host}:${config.port}`);

  process.once("SIGINT", () => requestShutdown("SIGINT"));
  process.once("SIGTERM", () => requestShutdown("SIGTERM"));
}

try {
  await main();
} catch (error: unknown) {
  console.error("Server startup failed", error);
  try {
    await browserService.close();
  } catch {
    // Preserve the original startup failure.
  }
  process.exitCode = 1;
}
