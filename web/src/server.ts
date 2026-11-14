import { once } from "node:events";
import type { Server } from "node:http";
import { createApiServer } from "./api/index";
import { getApiRoutes } from "./api/route";
import { config } from "./config";
import { browserService } from "./services/browser-service";
import { browserSession } from "./services/browser-session";
import { mcpService } from "./services/mcp-service";
import { registerShutdownHandler, shutdown } from "./shutdown";

async function listen(server: Server): Promise<void> {
  server.listen(config.port, config.host);
  await once(server, "listening");
}

async function closeServer(server: Server): Promise<void> {
  server.close();
  await once(server, "close");
}

async function main(): Promise<void> {
  console.log("Starting Camoufox...");
  await browserService.start();
  const server = createApiServer();
  await listen(server);
  registerShutdownHandler(async () => {
    await Promise.all([closeServer(server), browserSession.close(), browserService.close(), mcpService.close()]);
  });
  // Signals are only caught after cleanup is registered: a signal during startup must keep the
  // default behavior, otherwise shutdown would run an empty handler list and the process would hang.
  // `once` keeps a second Ctrl+C as the force-quit escape hatch when cleanup gets stuck.
  process.once("SIGINT", () => shutdown("SIGINT"));
  process.once("SIGTERM", () => shutdown("SIGTERM"));

  console.log("Supported endpoints:");
  for (const route of getApiRoutes()) console.log(`  ${route.method.padEnd(5)}${route.path}`);
  console.log(`Web server listening at http://${config.host}:${config.port}`);
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
