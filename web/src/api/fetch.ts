import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, HttpStatus, optionalString, readJsonBody, requireObject, requireString, sendOk } from "../http";
import { browserService } from "../services/browser-service";
import { extractPageContent } from "../services/page-content";
import { captureScreenshot, validateScreenshotPath } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

/** How long a parsed document may keep hydrating before the content is read anyway. */
const SETTLE_TIMEOUT_MS = 5_000;

export interface FetchResponse {
  url: string;
  finalUrl: string;
  title: string;
  description: string;
  author: string;
  published: string;
  site: string;
  domain: string;
  language: string;
  favicon: string;
  image: string;
  content: string;
  contentType: "markdown";
  wordCount: number;
  screenshotPath: string;
  screenshotError: string;
}

export class FetchApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/fetch";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const url = requireString(body.url, "url");
    const screenshotPath = optionalString(body.screenshotPath, "screenshotPath");
    // Reject an unusable screenshot path before spending a browser page on the navigation.
    validateScreenshotPath(screenshotPath);
    sendOk(response, await this.fetch(url, screenshotPath));
  }

  private async fetch(rawUrl: string, screenshotPath?: string): Promise<FetchResponse> {
    let requestedUrl: URL;
    try {
      requestedUrl = new URL(rawUrl);
    } catch {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_URL", "url must be a valid absolute URL");
    }
    const page = await browserService.openPage();
    try {
      await page.goto(requestedUrl.href, { waitUntil: "domcontentloaded" });
      // Hydration is best effort: a page that polls keeps the network busy forever, so waiting for
      // `networkidle` inside the navigation used to turn a readable page into a 504.
      await page.waitForLoadState("networkidle", { timeout: SETTLE_TIMEOUT_MS }).catch(() => undefined);
      const finalUrl = page.url();
      const content = await extractPageContent(page);
      const screenshot = await captureScreenshot(page, screenshotPath);
      return {
        url: requestedUrl.href,
        finalUrl,
        ...content,
        contentType: "markdown",
        ...screenshot,
      };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      if (error instanceof Error && error.name === "TimeoutError") throw new HttpError(HttpStatus.GATEWAY_TIMEOUT, "NAVIGATION_TIMEOUT", "Page navigation timed out");
      console.error(error);
      throw new HttpError(HttpStatus.BAD_GATEWAY, "FETCH_FAILED", "Page content could not be fetched");
    } finally {
      await page.close().catch(() => undefined);
    }
  }
}

registerApi(new FetchApi());
