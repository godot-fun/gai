import type { BrowserContext, Page } from "playwright-core";
import { config } from "../config";
import { Camoufox } from "camoufox";
import { HttpError, HttpStatus } from "../http";

function unavailable(message: string): HttpError {
  return new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", message);
}

export class BrowserService {
  private context: BrowserContext | null = null;
  private host: Page | null = null;
  private launching: Promise<void> | null = null;
  private tabLock = Promise.resolve();

  async start(): Promise<void> {
    await this.ensure();
  }

  isReady(): boolean {
    return this.host !== null && !this.host.isClosed();
  }

  /** Opens a tab. Caller must close the returned page. */
  async openPage(): Promise<Page> {
    await this.ensure();
    const page = await this.openTab();
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    page.setDefaultTimeout(config.navigationTimeoutMs);
    return page;
  }

  async close(): Promise<void> {
    if (this.launching !== null) await this.launching.catch(() => undefined);
    const context = this.context;
    this.context = null;
    this.host = null;
    if (context === null) return;
    try {
      await context.close();
    } catch (error) {
      console.error("Camoufox close failed", error);
    }
  }

  private async ensure(): Promise<void> {
    if (this.isReady()) return;
    this.launching ??= this.launch().finally(() => { this.launching = null; });
    await this.launching;
  }

  private async launch(): Promise<void> {
    let context: BrowserContext;
    try {
      context = await Camoufox({
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
    } catch (error) {
      console.error("Camoufox launch failed", error);
      throw unavailable("Browser could not be started");
    }

    const pages = context.pages();
    const host = pages[0];
    if (host === undefined) {
      await context.close().catch(() => undefined);
      throw unavailable("Browser could not be started");
    }
    // Keep the first window; Firefox tears the context down when the last window closes.
    await Promise.all(pages.slice(1).map((page) => page.close().catch(() => undefined)));
    context.on("close", () => {
      // Intentionally closed paths null this.context first, so this only fires on crashes.
      if (this.context !== context) return;
      console.warn("Camoufox context closed unexpectedly; it will relaunch on the next request");
      this.context = null;
      this.host = null;
    });
    this.host = host;
    this.context = context;
  }

  private openTab(): Promise<Page> {
    const run = this.tabLock.then(async () => {
      const context = this.context;
      const host = this.host;
      if (context === null || host === null || host.isClosed()) throw unavailable("Browser is unavailable");
      // context.newPage() opens a new OS window in Firefox; window.open stays in the host window.
      const [page] = await Promise.all([
        context.waitForEvent("page"),
        host.evaluate(() => window.open("about:blank", "_blank")),
      ]);
      return page;
    });
    this.tabLock = run.then(() => undefined, () => undefined);
    return run;
  }
}

export const browserService = new BrowserService();
