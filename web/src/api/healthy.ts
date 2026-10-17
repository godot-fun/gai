import type { ServerResponse } from "node:http";
import { sendJson } from "../http";
import type { BrowserService } from "../services/browser-service";

export function handleHealthy(response: ServerResponse, browserService: Pick<BrowserService, "isReady">, startedAt: number): void {
  const ready = browserService.isReady();
  sendJson(response, ready ? 200 : 503, {
    status: ready ? "ok" : "unavailable",
    browser: ready ? "ready" : "disconnected",
    uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
  });
}
