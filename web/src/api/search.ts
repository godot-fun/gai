import type { IncomingMessage, ServerResponse } from "node:http";
import type { Page } from "playwright-core";
import { isProxyEnabled } from "../config";
import { HttpError, HttpStatus, readJsonBody, requireObject, sendOk } from "../http";
import { browserService } from "../services/browser-service";
import { captureScreenshot } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

const DEFAULT_RESULT_COUNT = 10;
const MAX_RESULT_COUNT = 100;

export enum SearchEngine {
  Bing = "bing",
  Google = "google",
}

const SEARCH_ENGINES = Object.values(SearchEngine);

export interface SearchResult {
  position: number;
  title: string;
  url: string;
  snippet: string;
}

export interface SearchResponse {
  query: string;
  results: SearchResult[];
  screenshotPath: string;
  screenshotError: string;
}

export class SearchApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/search";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    if (typeof body.query !== "string") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "query must be a string");
    if (body.count !== undefined && typeof body.count !== "number") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "count must be a number");
    if (body.screenshotPath !== undefined && typeof body.screenshotPath !== "string") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "screenshotPath must be a string");
    if (body.engine !== undefined && !SEARCH_ENGINES.includes(body.engine as SearchEngine)) {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "engine must be bing or google");
    }
    sendOk(response, await this.search(body.query, body.count, body.screenshotPath, body.engine as SearchEngine | undefined));
  }

  private async search(query: string, count: number = DEFAULT_RESULT_COUNT, screenshotPath?: string, engine?: SearchEngine): Promise<SearchResponse> {
    if (query.trim() === "") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "query must not be empty");
    if (!Number.isSafeInteger(count) || count < 1 || count > MAX_RESULT_COUNT) {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `count must be an integer between 1 and ${MAX_RESULT_COUNT}`);
    }

    const selectedEngine = engine ?? (isProxyEnabled() ? SearchEngine.Google : SearchEngine.Bing);
    try {
      await using browserPage = await browserService.acquirePage();
      const results = selectedEngine === SearchEngine.Google
        ? await this.searchGoogle(browserPage.page, query.trim(), count)
        : await this.searchBing(browserPage.page, query.trim(), count);
      const screenshot = await captureScreenshot(browserPage.page, screenshotPath);
      return { query: query.trim(), results, ...screenshot };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      const engineName = selectedEngine === SearchEngine.Google ? "Google" : "Bing";
      if (error instanceof Error && error.name === "TimeoutError") throw new HttpError(HttpStatus.GATEWAY_TIMEOUT, "NAVIGATION_TIMEOUT", `${engineName} search timed out`);
      console.error(error);
      throw new HttpError(HttpStatus.BAD_GATEWAY, "SEARCH_FAILED", `${engineName} search failed`);
    }
  }

  private async searchGoogle(page: Page, query: string, count: number): Promise<SearchResult[]> {
    const searchUrl = new URL("https://www.google.com/search");
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("num", String(count));
    searchUrl.searchParams.set("udm", "14");
    await page.goto(searchUrl.href, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#search a:has(h3)", { state: "visible" });

    const rawResults = await page.locator("#search a:has(h3)").evaluateAll((anchors) => anchors.map((element) => {
      const anchor = element as HTMLAnchorElement;
      const container = anchor.closest<HTMLElement>(".MjjYud, .g");
      const snippet = container?.querySelector<HTMLElement>(".VwiC3b, .IsZvec, [data-sncf]");
      return {
        title: anchor.querySelector<HTMLElement>("h3")?.textContent?.trim() ?? "",
        url: anchor.href,
        snippet: snippet?.textContent?.trim() ?? "",
      };
    }));

    return this.normalizeResults(rawResults, count);
  }

  private async searchBing(page: Page, query: string, count: number): Promise<SearchResult[]> {
    const searchUrl = new URL("https://www.bing.com/search");
    searchUrl.searchParams.set("q", query);
    searchUrl.searchParams.set("count", String(count));
    await page.goto(searchUrl.href, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#b_results > li.b_algo", { state: "visible" });

    const rawResults = await page.locator("#b_results > li.b_algo").evaluateAll((items) => items.map((item) => {
      const anchor = item.querySelector<HTMLAnchorElement>("h2 a");
      const snippet = item.querySelector<HTMLElement>(".b_caption p, .b_snippet, p");
      return {
        title: anchor?.textContent?.trim() ?? "",
        url: anchor?.href ?? "",
        snippet: snippet?.textContent?.trim() ?? "",
      };
    }));

    return this.normalizeResults(rawResults, count);
  }

  private normalizeResults(rawResults: Array<{ title: string; url: string; snippet: string }>, count: number): SearchResult[] {
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
