import type { IncomingMessage, ServerResponse } from "node:http";

export interface ApiRoute {
  readonly method: string;
  readonly path: string;
  handle(request: IncomingMessage, response: ServerResponse): Promise<void> | void;
}

const routes: ApiRoute[] = [];

export function registerApi(route: ApiRoute): void {
  if (routes.some((registered) => registered.method === route.method && registered.path === route.path)) throw new Error(`Duplicate API route: ${route.method} ${route.path}`);
  routes.push(route);
}

export function getApiRoutes(): readonly ApiRoute[] {
  return routes;
}
