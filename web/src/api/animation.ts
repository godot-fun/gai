import type { IncomingMessage, ServerResponse } from "node:http";
import { readJsonBody, requireObject, requireString, sendOk } from "../http";
import { animationService } from "../services/animation-service";
import { registerApi } from "./route";

registerApi({
  method: "POST",
  path: "/animation/create",
  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const animation = await animationService.create({
      htmlPath: requireString(body.htmlPath, "htmlPath"),
      outputDirectory: requireString(body.outputDirectory, "outputDirectory"),
    });
    sendOk(response, { animation });
  },
});

registerApi({
  method: "POST",
  path: "/animation/query",
  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    sendOk(response, await animationService.query(
      requireString(body.animation, "animation"),
      requireString(body.outputDirectory, "outputDirectory"),
    ));
  },
});
