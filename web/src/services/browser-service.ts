import type { BrowserContext, Page } from "playwright-core";
import { config } from "../config";
import { Camoufox } from "camoufox";
import { HttpError, HttpStatus } from "../http";

/** How long a page handed out here may keep loading before the caller reads it anyway. */
export const PAGE_SETTLE_TIMEOUT_MS = 5_000;

function unavailable(message: string): HttpError {
  return new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", message);
}

/**
 * Turns a failed page operation into the error the agent sees: a Playwright timeout blames the
 * upstream site (504), everything else stays a generic gateway failure (502).
 */
export function pageFailure(error: unknown, what: string, code: string): HttpError {
  if (error instanceof Error && error.name === "TimeoutError") return new HttpError(HttpStatus.GATEWAY_TIMEOUT, "NAVIGATION_TIMEOUT", `${what} timed out`);
  console.error(what, error);
  return new HttpError(HttpStatus.BAD_GATEWAY, code, `${what} failed`);
}

export class BrowserService {
  private context: BrowserContext | null = null;
  private launching: Promise<BrowserContext> | null = null;

  async start(): Promise<void> {
    await this.getContext();
  }

  isReady(): boolean {
    return this.context !== null;
  }

  /** Opens a page. Caller must close it. Keep at least the launch blank page alive — Firefox exits if every page is closed. */
  async openPage(): Promise<Page> {
    const page = await (await this.getContext()).newPage();
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    page.setDefaultTimeout(config.navigationTimeoutMs);
    return page;
  }

  async close(): Promise<void> {
    if (this.launching !== null) await this.launching.catch(() => undefined);
    const context = this.context;
    this.context = null;
    if (context === null) return;
    try {
      await context.close();
    } catch (error) {
      console.error("Camoufox close failed", error);
    }
  }

  private async getContext(): Promise<BrowserContext> {
    if (this.context !== null) return this.context;
    // Concurrent callers share one launch, and a failed launch is forgotten so the next one retries.
    const launching = (this.launching ??= this.launch());
    try {
      return await launching;
    } finally {
      this.launching = null;
    }
  }

  private async launch(): Promise<BrowserContext> {
    try {
      const context = await Camoufox({
        persistent_context: true,
        user_data_dir: config.userDataDir,
        headless: config.headless,
        proxy: config.proxy ? { server: config.proxy } : undefined,
        geoip: true,
        i_know_what_im_doing: true,
        firefox_user_prefs: {
          "browser.sessionstore.resume_from_crash": false,
          "browser.sessionstore.max_resumed_crashes": 0,
          "browser.startup.page": 0,
        },
      });
      // Drop session-restored extras; keep pages[0] so the context stays alive.
      await Promise.all(context.pages().slice(1).map((page) => page.close().catch(() => undefined)));
      context.on("close", () => {
        if (this.context === context) this.context = null;
      });
      this.context = context;
      return context;
    } catch (error) {
      console.error("Camoufox launch failed", error);
      throw unavailable("Browser could not be started");
    }
  }
}

export const browserService = new BrowserService();
