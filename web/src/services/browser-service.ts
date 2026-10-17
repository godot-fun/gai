import { launchPersistentContext } from "cloakbrowser";
import type { BrowserContext, Page } from "playwright-core";
import { loadConfig } from "../config";
import { HttpError, HttpStatus } from "../http";

interface BrowserServiceOptions {
  headless: boolean;
  userDataDir: string;
  proxy: string;
  maxConcurrency: number;
  navigationTimeoutMs: number;
}

interface QueueEntry {
  resolve: () => void;
  reject: (error: Error) => void;
}

const releasePage = Symbol("releasePage");

class BrowserPageLease implements AsyncDisposable {
  constructor(public readonly page: Page, private readonly service: BrowserService) {}

  async [Symbol.asyncDispose](): Promise<void> {
    try {
      await this.page.close();
    } catch {
      // Releasing the concurrency slot is more important than a page-close failure.
    } finally {
      this.service[releasePage]();
    }
  }
}

export class BrowserService {
  private context: BrowserContext | null = null;
  private activePages = 0;
  private readonly queue: QueueEntry[] = [];
  private closing = false;

  constructor(private readonly options: BrowserServiceOptions) {
    this.handleContextClose = this.handleContextClose.bind(this);
  }

  async start(): Promise<void> {
    this.context = await launchPersistentContext({
      headless: this.options.headless,
      userDataDir: this.options.userDataDir,
      ...(this.options.proxy === "" ? {} : { proxy: this.options.proxy }),
    });
    this.context.on("close", this.handleContextClose);
    await Promise.all(this.context.pages().map((page) => page.close()));
  }

  isReady(): boolean {
    return this.context !== null && !this.closing;
  }

  async acquirePage(): Promise<BrowserPageLease> {
    await this.acquire();
    try {
      const context = this.context;
      if (context === null) throw new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", "Browser is unavailable");
      const page = await context.newPage();
      page.setDefaultNavigationTimeout(this.options.navigationTimeoutMs);
      page.setDefaultTimeout(this.options.navigationTimeoutMs);
      return new BrowserPageLease(page, this);
    } catch (error) {
      this[releasePage]();
      throw error;
    }
  }

  async close(): Promise<void> {
    this.closing = true;
    this.rejectQueue(new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", "Server is shutting down"));
    const context = this.context;
    this.context = null;
    if (context !== null) await context.close();
  }

  private async acquire(): Promise<void> {
    if (!this.isReady()) throw new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", "Browser is unavailable");
    if (this.activePages < this.options.maxConcurrency) {
      this.activePages += 1;
      return;
    }
    await new Promise<void>((resolve, reject) => this.queue.push({ resolve, reject }));
  }

  [releasePage](): void {
    const next = this.queue.shift();
    if (next !== undefined && this.isReady()) {
      next.resolve();
      return;
    }
    this.activePages = Math.max(0, this.activePages - 1);
    if (next !== undefined) next.reject(new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", "Browser is unavailable"));
  }

  private rejectQueue(error: Error): void {
    for (const entry of this.queue.splice(0)) entry.reject(error);
  }

  private handleContextClose(): void {
    this.context = null;
    this.rejectQueue(new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", "Browser is disconnected"));
  }
}

const config = loadConfig();
export const browserService = new BrowserService({
  headless: config.headless,
  userDataDir: config.userDataDir,
  proxy: config.proxy,
  maxConcurrency: config.browserMaxConcurrency,
  navigationTimeoutMs: config.navigationTimeoutMs,
});
