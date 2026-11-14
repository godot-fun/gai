import { createServer } from "node:http";
import type { IncomingMessage, Server, ServerResponse } from "node:http";
import { config } from "../config";
import { HttpError, HttpStatus, sendError, sendJson } from "../http";
// Importing a route module registers it through `registerApi`.
import "./browser";
import "./fetch";
import "./healthy";
import "./mcp";
import "./search";
import "./stop";
import { getApiRoutes, type ApiRoute } from "./route";

// Routing only needs the request path, so a fixed base keeps a hostile Host header out of URL parsing.
const BASE_URL = "http://localhost";

/** The single definition of a route's identity: a method and a path, exactly as registered. */
function routeKey(method: string, path: string): string {
  return `${method} ${path}`;
}

async function route(request: IncomingMessage, response: ServerResponse, routes: ReadonlyMap<string, ApiRoute>): Promise<void> {
  const pathname = new URL(request.url ?? "/", BASE_URL).pathname;
  const matchedRoute = routes.get(routeKey(request.method ?? "", pathname));
  if (matchedRoute === undefined) throw new HttpError(HttpStatus.NOT_FOUND, "NOT_FOUND", "Route not found");
  await matchedRoute.handle(request, response);
}

export function createApiServer(): Server {
  const routes = new Map(getApiRoutes().map((registered) => [routeKey(registered.method, registered.path), registered]));

  async function handleRequest(request: IncomingMessage, response: ServerResponse): Promise<void> {
    function handleTimeout(): void {
      if (!response.headersSent) sendJson(response, HttpStatus.GATEWAY_TIMEOUT, { error: { code: "REQUEST_TIMEOUT", message: "Request timed out" } });
      else response.destroy();
    }

    response.setTimeout(config.requestTimeoutMs, handleTimeout);
    try {
      await route(request, response, routes);
    } catch (error: unknown) {
      if (!response.headersSent) sendError(response, error);
      else response.destroy(error instanceof Error ? error : undefined);
    }
  }

  return createServer(handleRequest);
}
