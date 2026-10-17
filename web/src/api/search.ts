import type { IncomingMessage, ServerResponse } from "node:http";
import type { Page } from "playwright-core";
import { HttpError, HttpStatus, readJsonBody, requireObject, sendOk } from "../http";
import { browserService } from "../services/browser-service";
import { registerApi, type ApiRoute } from "./route";

const DEFAULT_RESULT_COUNT = 10;
const MAX_RESULT_COUNT = 100;

export interface SearchResult {
  position: number;
  title: string;
  url: string;
  snippet: string;
}

export interface SearchResponse {
  query: string;
  results: SearchResult[];
}

export class SearchApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/search";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    if (typeof body.query !== "string") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "query must be a string");
    if (body.count !== undefined && typeof body.count !== "number") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "count must be a number");
    sendOk(response, await this.search(body.query, body.count));
  }

  private async search(query: string, count: number = DEFAULT_RESULT_COUNT): Promise<SearchResponse> {
    if (query.trim() === "") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "query must not be empty");
    if (!Number.isSafeInteger(count) || count < 1 || count > MAX_RESULT_COUNT) {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `count must be an integer between 1 and ${MAX_RESULT_COUNT}`);
    }

    try {
      const results = await browserService.withPage(async (page) => this.searchBing(page, query.trim(), count));
      return { query: query.trim(), results };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      if (error instanceof Error && error.name === "TimeoutError") throw new HttpError(HttpStatus.GATEWAY_TIMEOUT, "NAVIGATION_TIMEOUT", "Bing search timed out");
      console.error(error);
      throw new HttpError(HttpStatus.BAD_GATEWAY, "SEARCH_FAILED", "Bing search failed");
    }
  }

  private async searchBing(page: Page, query: string, count: number): Promise<SearchResult[]> {
    const searchUrl = new URL("https://www.bing.com/search");
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("count", String(count));
    await page.goto(searchUrl.href, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#b_results", { state: "attached" });

    const rawResults = await page.locator("#b_results > li.b_algo").evaluateAll((items) => items.map((item) => {
      const anchor = item.querySelector<HTMLAnchorElement>("h2 a");
      const snippet = item.querySelector<HTMLElement>(".b_caption p, .b_snippet, p");
      return {
        title: anchor?.textContent?.trim() ?? "",
        url: anchor?.href ?? "",
        snippet: snippet?.textContent?.trim() ?? "",
      };
    }));

    const seen = new Set<string>();
    const results: SearchResult[] = [];
    for (const result of rawResults) {
      if (result.title === "" || result.url === "" || seen.has(result.url)) continue;
      let url: URL;
      try {
        url = new URL(result.url);
      } catch {
        continue;
      }
      if (url.protocol !== "http:" && url.protocol !== "https:") continue;
      seen.add(url.href);
      results.push({ position: results.length + 1, title: result.title, url: url.href, snippet: result.snippet });
      if (results.length >= count) break;
    }
    return results;
  }
}

registerApi(new SearchApi());
