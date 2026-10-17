import type { IncomingMessage, ServerResponse } from "node:http";

const MAX_REQUEST_BODY_BYTES = 1024 * 1024;

export const HttpStatus = {
  OK: 200,
  BAD_REQUEST: 400,
  NOT_FOUND: 404,
  CONTENT_TOO_LARGE: 413,
  INTERNAL_SERVER_ERROR: 500,
  BAD_GATEWAY: 502,
  SERVICE_UNAVAILABLE: 503,
  GATEWAY_TIMEOUT: 504,
} as const;

export class HttpError extends Error {
  constructor(public readonly status: number, public readonly code: string, message: string) {
    super(message);
    this.name = "HttpError";
  }
}

export async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > MAX_REQUEST_BODY_BYTES) throw new HttpError(HttpStatus.CONTENT_TOO_LARGE, "REQUEST_TOO_LARGE", "Request body is too large");
    chunks.push(buffer);
  }

  if (chunks.length === 0) throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "A JSON request body is required");
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8")) as unknown;
  } catch {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_JSON", "Request body must be valid JSON");
  }
}

export function sendJson(response: ServerResponse, status: number, value: unknown): void {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body),
    "cache-control": "no-store",
  });
  response.end(body);
}

export function sendOk(response: ServerResponse, value: unknown): void {
  sendJson(response, HttpStatus.OK, value);
}

export function sendError(response: ServerResponse, error: unknown): void {
  if (error instanceof HttpError) {
    sendJson(response, error.status, { error: { code: error.code, message: error.message } });
    return;
  }

  console.error(error);
  sendJson(response, HttpStatus.INTERNAL_SERVER_ERROR, { error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred" } });
}

export function requireObject(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "Request body must be a JSON object");
  }
  return value as Record<string, unknown>;
}
