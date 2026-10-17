import type { IncomingMessage, ServerResponse } from "node:http";
import { Defuddle } from "defuddle/node";
import { HttpError, HttpStatus, readJsonBody, requireObject, sendOk } from "../http";
import { browserService } from "../services/browser-service";
import { captureScreenshot } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

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
    if (typeof body.url !== "string") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "url must be a string");
    if (body.screenshotPath !== undefined && typeof body.screenshotPath !== "string") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "screenshotPath must be a string");
    sendOk(response, await this.fetch(body.url, body.screenshotPath));
  }

  private async fetch(rawUrl: string, screenshotPath?: string): Promise<FetchResponse> {
    let requestedUrl: URL;
    try {
      requestedUrl = new URL(rawUrl);
    } catch {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_URL", "url must be a valid absolute URL");
    }
    try {
      await using browserPage = await browserService.acquirePage();
      const page = browserPage.page;
      await page.goto(requestedUrl.href, { waitUntil: "domcontentloaded" });
      const finalUrl = page.url();
      const html = await page.content();
      const result = await Defuddle(html, finalUrl, { markdown: true, useAsync: false });
      const screenshot = await captureScreenshot(page, screenshotPath);
      return {
        url: requestedUrl.href,
        finalUrl,
        title: result.title,
        description: result.description,
        author: result.author,
        published: result.published,
        site: result.site,
        domain: result.domain,
        language: result.language,
        favicon: result.favicon,
        image: result.image,
        content: result.content,
        contentType: "markdown",
        wordCount: result.wordCount,
        ...screenshot,
      };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      if (error instanceof Error && error.name === "TimeoutError") throw new HttpError(HttpStatus.GATEWAY_TIMEOUT, "NAVIGATION_TIMEOUT", "Page navigation timed out");
      console.error(error);
      throw new HttpError(HttpStatus.BAD_GATEWAY, "FETCH_FAILED", "Page content could not be fetched");
    }
  }
}

registerApi(new FetchApi());
