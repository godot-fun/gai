import type { IncomingMessage, ServerResponse } from "node:http";
import { config } from "../config";
import { HttpError, HttpStatus, optionalPositiveNumber, readJsonBody, requireObject, requireString, sendOk } from "../http";
import { animationService } from "../services/animation-service";
import { registerApi } from "./route";

/** Playing an animation is only useful on screen: a headless window has nothing to capture. */
function requireVisibleBrowser(): void {
  if (config.headless) {
    throw new HttpError(
      HttpStatus.PRECONDITION_FAILED,
      "HEADLESS_BROWSER",
      "Animation playback needs a visible browser window: set BROWSER_HEADLESS=false and keep the window on screen",
    );
  }
}

registerApi({
  method: "POST",
  path: "/animation/open",
  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    requireVisibleBrowser();
    // Answers after the page has painted its paused first frame: the caller can then place the
    // window and start capturing without the load time landing inside the recording.
    const body = requireObject(await readJsonBody(request));
    sendOk(response, await animationService.open(
      requireString(body.htmlPath, "htmlPath"),
      optionalPositiveNumber(body.duration, "duration"),
    ));
  },
});

registerApi({
  method: "POST",
  path: "/animation/play",
  async handle(_request: IncomingMessage, response: ServerResponse): Promise<void> {
    requireVisibleBrowser();
    // Presses Space and answers at once: the page has been open and paused since /animation/open.
    sendOk(response, await animationService.play());
  },
});

registerApi({
  method: "POST",
  path: "/animation/close",
  async handle(_request: IncomingMessage, response: ServerResponse): Promise<void> {
    // Closes the playback tab so the recording leaves nothing on screen behind it.
    await animationService.close();
    sendOk(response, { status: "closed" });
  },
});
