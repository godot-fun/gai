import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { HttpError, HttpStatus, sendError, sendJson } from "../http";
import "./fetch";
import "./healthy";
import "./search";
import { getApiRoutes, type ApiRoute } from "./route";

export interface ApiOptions {
  requestTimeoutMs: number;
}

async function route(request: IncomingMessage, response: ServerResponse, routes: readonly ApiRoute[]): Promise<void> {
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
  const matchedRoute = routes.find((candidate) => candidate.method === request.method && candidate.path === url.pathname);
  if (matchedRoute === undefined) throw new HttpError(HttpStatus.NOT_FOUND, "NOT_FOUND", "Route not found");
  await matchedRoute.handle(request, response);
}

export function createApiServer(options: ApiOptions): Server {
  const routes = getApiRoutes();
  return createServer((request, response) => {
    response.setTimeout(options.requestTimeoutMs, () => {
      if (!response.headersSent) sendJson(response, HttpStatus.GATEWAY_TIMEOUT, { error: { code: "REQUEST_TIMEOUT", message: "Request timed out" } });
      else response.destroy();
    });
    void route(request, response, routes).catch((error: unknown) => {
      if (!response.headersSent) sendError(response, error);
      else response.destroy(error instanceof Error ? error : undefined);
    });
  });
}
