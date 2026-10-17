import type { IncomingMessage, ServerResponse } from "node:http";
import { sendOk } from "../http";
import { registerApi, type ApiRoute } from "./route";

export class StopApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/stop";

  handle(_request: IncomingMessage, response: ServerResponse): void {
    sendOk(response, { status: "stopping" });
    setImmediate(() => process.kill(process.pid, "SIGTERM"));
  }
}

registerApi(new StopApi());
