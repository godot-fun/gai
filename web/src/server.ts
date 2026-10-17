import { once } from "node:events";
import type { Server } from "node:http";
import { createApiServer } from "./api/index";
import { getApiRoutes } from "./api/route";
import { loadConfig } from "./config";
import { browserService } from "./services/browser-service";

const config = loadConfig();

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
  const server = createApiServer({ requestTimeoutMs: config.requestTimeoutMs });
  await listen(server);
  console.log("Supported endpoints:");
  for (const route of getApiRoutes()) console.log(`  ${route.method.padEnd(5)}${route.path}`);
  console.log(`Web server listening at http://${config.host}:${config.port}`);

  let shuttingDown = false;
  async function shutdown(signal: NodeJS.Signals): Promise<void> {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Received ${signal}; shutting down...`);
    try {
      await Promise.all([closeServer(server), browserService.close()]);
      process.exitCode = 0;
    } catch (error) {
      console.error("Shutdown failed", error);
      process.exitCode = 1;
    }
  }
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
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
