import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { config } from "../config";
import { HttpError, HttpStatus, sendError, sendJson } from "../http";
import "./fetch";
import "./healthy";
import "./mcp";
import "./search";
import "./stop";
import { getApiRoutes, type ApiRoute } from "./route";

// Routing only needs the request path, so a fixed base keeps a hostile Host header out of URL parsing.
const BASE_URL = "http://localhost";

function routeKey(route: ApiRoute): string {
  return `${route.method} ${route.path}`;
}

async function route(request: IncomingMessage, response: ServerResponse, routes: ReadonlyMap<string, ApiRoute>): Promise<void> {
  const pathname = new URL(request.url ?? "/", BASE_URL).pathname;
  const matchedRoute = routes.get(`${request.method} ${pathname}`);
  if (matchedRoute === undefined) throw new HttpError(HttpStatus.NOT_FOUND, "NOT_FOUND", "Route not found");
  await matchedRoute.handle(request, response);
}

export function createApiServer(): Server {
  const routes = new Map(getApiRoutes().map((registered) => [routeKey(registered), registered]));

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
