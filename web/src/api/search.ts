import type { IncomingMessage, ServerResponse } from "node:http";
import type { Page } from "playwright-core";
import { isProxyEnabled } from "../config";
import { HttpError, HttpStatus, optionalString, readJsonBody, requireObject, requireString, sendOk } from "../http";
import { browserService, pageFailure } from "../services/browser-service";
import { captureScreenshot, validateScreenshotPath } from "../services/screenshot-service";
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

/** What an engine page yields before filtering; a result may still be blank or unusable here. */
interface RawSearchResult {
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
    const query = requireString(body.query, "query").trim();
    const count = readCount(body.count);
    const engine = readEngine(body.engine);
    const screenshotPath = optionalString(body.screenshotPath, "screenshotPath");
    // Reject an unusable screenshot path before spending a browser page on the search.
    validateScreenshotPath(screenshotPath);
    sendOk(response, await runSearch(query, count, screenshotPath, engine));
  }
}

/** Reads one engine's results through a short-lived page: navigate, wait for results, extract, capture, close. */
async function runSearch(query: string, count: number = DEFAULT_RESULT_COUNT, screenshotPath?: string, engine?: SearchEngine): Promise<SearchResponse> {
  if (!Number.isSafeInteger(count) || count < 1 || count > MAX_RESULT_COUNT) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `count must be an integer between 1 and ${MAX_RESULT_COUNT}`);
  }

  const selectedEngine = engine ?? (isProxyEnabled() ? SearchEngine.Google : SearchEngine.Bing);
  const engineName = selectedEngine === SearchEngine.Google ? "Google" : "Bing";
  const page = await browserService.openPage();
  try {
    const results = selectedEngine === SearchEngine.Google
      ? await searchGoogle(page, query, count)
      : await searchBing(page, query, count);
    const screenshot = await captureScreenshot(page, screenshotPath);
    return { query, results, ...screenshot };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw pageFailure(error, `${engineName} search`, "SEARCH_FAILED");
  } finally {
    await page.close().catch(() => undefined);
  }
}

async function searchGoogle(page: Page, query: string, count: number): Promise<SearchResult[]> {
  const searchUrl = new URL("https://www.google.com/search");
  searchUrl.searchParams.set("q", query);
  searchUrl.searchParams.set("num", String(count));
  searchUrl.searchParams.set("udm", "14");
  await page.goto(searchUrl.href, { waitUntil: "load" });
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

  return normalizeSearchResults(rawResults, count);
}

async function searchBing(page: Page, query: string, count: number): Promise<SearchResult[]> {
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

  return normalizeSearchResults(rawResults, count);
}

/**
 * Drops empty, non-http, and repeated results, and numbers what survives.
 *
 * Dedupe uses the normalized `URL.href`: an engine lists the same target with differently spelled
 * hrefs (`HTTPS://Example.com/x`, a bare host vs. a trailing slash), and comparing the raw strings
 * would report it twice.
 */
export function normalizeSearchResults(rawResults: readonly RawSearchResult[], count: number): SearchResult[] {
  const seen = new Set<string>();
  const results: SearchResult[] = [];
  for (const result of rawResults) {
    if (result.title === "" || result.url === "") continue;
    let url: URL;
    try {
      url = new URL(result.url);
    } catch {
      continue;
    }
    if (url.protocol !== "http:" && url.protocol !== "https:") continue;
    if (seen.has(url.href)) continue;
    seen.add(url.href);
    results.push({ position: results.length + 1, title: result.title, url: url.href, snippet: result.snippet });
    if (results.length >= count) break;
  }
  return results;
}

/** `count` and `engine` are optional, but a wrong type is the caller's mistake, not a search failure. */
function readCount(value: unknown): number | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "number") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "count must be a number");
  return value;
}

function readEngine(value: unknown): SearchEngine | undefined {
  if (value === undefined) return undefined;
  if (!SEARCH_ENGINES.includes(value as SearchEngine)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "engine must be bing or google");
  }
  return value as SearchEngine;
}

registerApi(new SearchApi());
