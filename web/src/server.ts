import type { Server } from "node:http";
import { createApiServer } from "./api/index";
import { FetchService } from "./api/fetch";
import { SearchService } from "./api/search";
import { loadConfig } from "./config";
import { BrowserService } from "./services/browser-service";

const config = loadConfig();
const browserService = new BrowserService({
  headless: config.headless,
  userDataDir: config.userDataDir,
  maxConcurrency: config.browserMaxConcurrency,
  navigationTimeoutMs: config.navigationTimeoutMs,
});
const searchService = new SearchService(browserService);
const fetchService = new FetchService(browserService);

async function listen(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(config.port, config.host, () => {
      server.off("error", reject);
      resolve();
    });
  });
}

async function closeServer(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => server.close((error) => error === undefined ? resolve() : reject(error)));
}

async function main(): Promise<void> {
  console.log("Starting CloakBrowser...");
  await browserService.start();
  const server = createApiServer({ browserService, searchService, fetchService }, { requestTimeoutMs: config.requestTimeoutMs });
  await listen(server);
  console.log("Supported endpoints:");
  console.log("  GET  /healthy");
  console.log("  POST /search");
  console.log("  POST /fetch");
  console.log(`Web server listening at http://${config.host}:${config.port}`);

  let shuttingDown = false;
  const shutdown = async (signal: string): Promise<void> => {
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
  };
  process.once("SIGINT", () => void shutdown("SIGINT"));
  process.once("SIGTERM", () => void shutdown("SIGTERM"));
}

main().catch(async (error: unknown) => {
  console.error("Server startup failed", error);
  await browserService.close().catch(() => undefined);
  process.exitCode = 1;
});
