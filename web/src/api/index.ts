import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { HttpError, sendError, sendJson } from "../http";
import type { BrowserService } from "../services/browser-service";
import { handleFetch, type FetchService } from "./fetch";
import { handleHealthy } from "./healthy";
import { handleSearch, type SearchService } from "./search";

export interface ApiServices {
  browserService: Pick<BrowserService, "isReady">;
  searchService: Pick<SearchService, "search">;
  fetchService: Pick<FetchService, "fetch">;
}

export interface ApiOptions {
  requestTimeoutMs: number;
  startedAt?: number;
}

async function route(request: IncomingMessage, response: ServerResponse, services: ApiServices, startedAt: number): Promise<void> {
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
  if (request.method === "GET" && url.pathname === "/healthy") {
    handleHealthy(response, services.browserService, startedAt);
    return;
  }
  if (request.method === "POST" && url.pathname === "/search") {
    await handleSearch(request, response, services.searchService);
    return;
  }
  if (request.method === "POST" && url.pathname === "/fetch") {
    await handleFetch(request, response, services.fetchService);
    return;
  }
  throw new HttpError(404, "NOT_FOUND", "Route not found");
}

export function createApiServer(services: ApiServices, options: ApiOptions): Server {
  const startedAt = options.startedAt ?? Date.now();
  return createServer((request, response) => {
    response.setTimeout(options.requestTimeoutMs, () => {
      if (!response.headersSent) sendJson(response, 504, { error: { code: "REQUEST_TIMEOUT", message: "Request timed out" } });
      else response.destroy();
    });
    void route(request, response, services, startedAt).catch((error: unknown) => {
      if (!response.headersSent) sendError(response, error);
      else response.destroy(error instanceof Error ? error : undefined);
    });
  });
}
