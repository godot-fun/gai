import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpStatus, sendJson } from "../http";
import { browserService } from "../services/browser-service";
import { registerApi, type ApiRoute } from "./route";

export class HealthyApi implements ApiRoute {
  readonly method = "GET";
  readonly path = "/healthy";

  constructor(private readonly startedAt = Date.now()) {}

  handle(_request: IncomingMessage, response: ServerResponse): void {
    const ready = browserService.isReady();
    sendJson(response, ready ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE, {
      status: ready ? "ok" : "unavailable",
      browser: ready ? "ready" : "disconnected",
      uptimeSeconds: Math.floor((Date.now() - this.startedAt) / 1000),
    });
  }
}

registerApi(new HealthyApi());
