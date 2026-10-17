import type { IncomingMessage, ServerResponse } from "node:http";
import { sendOk } from "../http";
import { registerApi, type ApiRoute } from "./route";

export class StopApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/stop";

  handle(_request: IncomingMessage, response: ServerResponse): void {
    response.once("finish", () => setTimeout(() => process.kill(process.pid, "SIGTERM"), 500));
    sendOk(response, { status: "stopping" });
  }
}

registerApi(new StopApi());
