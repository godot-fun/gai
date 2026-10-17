import type { IncomingMessage, ServerResponse } from "node:http";
import { Defuddle } from "defuddle/node";
import { HttpError, readJsonBody, requireObject, sendJson } from "../http";
import { BrowserService } from "../services/browser-service";

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
}

export class FetchService {
  constructor(private readonly browserService: BrowserService) {}

  async fetch(rawUrl: string): Promise<FetchResponse> {
    let requestedUrl: URL;
    try {
      requestedUrl = new URL(rawUrl);
    } catch {
      throw new HttpError(400, "INVALID_URL", "url must be a valid absolute URL");
    }
    try {
      return await this.browserService.withPage(async (page) => {
        await page.goto(requestedUrl.href, { waitUntil: "domcontentloaded" });
        const finalUrl = page.url();
        const html = await page.content();
        const result = await Defuddle(html, finalUrl, { markdown: true, useAsync: false });
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
        };
      });
    } catch (error) {
      if (error instanceof HttpError) throw error;
      if (error instanceof Error && error.name === "TimeoutError") throw new HttpError(504, "NAVIGATION_TIMEOUT", "Page navigation timed out");
      console.error(error);
      throw new HttpError(502, "FETCH_FAILED", "Page content could not be fetched");
    }
  }
}

export async function handleFetch(request: IncomingMessage, response: ServerResponse, fetchService: Pick<FetchService, "fetch">): Promise<void> {
  const body = requireObject(await readJsonBody(request));
  if (typeof body.url !== "string") throw new HttpError(400, "INVALID_REQUEST", "url must be a string");
  sendJson(response, 200, await fetchService.fetch(body.url));
}
