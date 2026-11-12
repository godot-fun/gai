import { launchPersistentContext } from "cloakbrowser";
import type { BrowserContext, Page } from "playwright-core";
import { config } from "../config";
import { HttpError, HttpStatus } from "../http";

interface QueueEntry {
  settle: (error?: Error) => void;
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

function unavailable(message: string): HttpError {
  return new HttpError(HttpStatus.SERVICE_UNAVAILABLE, "BROWSER_UNAVAILABLE", message);
}

export class BrowserService {
  private context: BrowserContext | null = null;
  private starting: Promise<BrowserContext> | null = null;
  private activePages = 0;
  private readonly queue: QueueEntry[] = [];
  private closing = false;

  constructor() {
    this.handleContextClose = this.handleContextClose.bind(this);
  }

  /** Starts the browser once; concurrent callers share one launch instead of spawning duplicates. */
  async start(): Promise<void> {
    await this.ensureContext();
  }

  isReady(): boolean {
    return this.context !== null && !this.closing;
  }

  async acquirePage(): Promise<BrowserPageLease> {
    await this.acquire();
    try {
      const context = this.context;
      if (context === null) throw unavailable("Browser is unavailable");
      const page = await context.newPage();
      page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
      page.setDefaultTimeout(config.navigationTimeoutMs);
      return new BrowserPageLease(page, this);
    } catch (error) {
      this[releasePage]();
      throw error;
    }
  }

  async close(): Promise<void> {
    this.closing = true;
    this.rejectQueue(unavailable("Server is shutting down"));
    const context = this.context;
    this.context = null;
    if (context === null) return;
    try {
      await context.close();
    } catch (error) {
      console.error("CloakBrowser close failed", error);
    }
  }

  private async acquire(): Promise<void> {
    await this.ensureContext();
    if (this.activePages < config.browserMaxConcurrency) {
      this.activePages += 1;
      return;
    }
    await this.waitForSlot();
  }

  /**
   * Returns the live context, launching (or relaunching after a crash) on demand.
   * A shutdown in progress rejects instead of starting a browser that nobody will close.
   */
  private ensureContext(): Promise<BrowserContext> {
    if (this.context !== null) return Promise.resolve(this.context);
    if (this.closing) return Promise.reject(unavailable("Server is shutting down"));
    this.starting ??= this.launchContext().finally(() => { this.starting = null; });
    return this.starting;
  }

  private async launchContext(): Promise<BrowserContext> {
    let context: BrowserContext;
    try {
      context = await launchPersistentContext({
        headless: config.headless,
        userDataDir: config.userDataDir,
        proxy: config.proxy || undefined,
      });
    } catch (error) {
      console.error("CloakBrowser launch failed", error);
      throw unavailable("Browser could not be started");
    }

    if (this.closing) {
      await context.close().catch(() => undefined);
      throw unavailable("Server is shutting down");
    }
    context.on("close", this.handleContextClose);
    this.context = context;
    return context;
  }

  private waitForSlot(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let timer: NodeJS.Timeout | undefined;
      const entry: QueueEntry = {
        settle: (error?: Error) => {
          clearTimeout(timer);
          const index = this.queue.indexOf(entry);
          if (index >= 0) this.queue.splice(index, 1);
          if (error === undefined) resolve();
          else reject(error);
        },
      };
      // A waiter that never receives a slot must not outlive the HTTP request that created it.
      timer = setTimeout(() => entry.settle(unavailable("Browser is busy")), config.requestTimeoutMs);
      this.queue.push(entry);
    });
  }

  [releasePage](): void {
    const next = this.queue.shift();
    if (next !== undefined && this.isReady()) {
      // Hand the slot over without touching the counter.
      next.settle();
      return;
    }
    this.activePages = Math.max(0, this.activePages - 1);
    if (next !== undefined) next.settle(unavailable("Browser is unavailable"));
  }

  private rejectQueue(error: Error): void {
    for (const entry of this.queue.splice(0)) entry.settle(error);
  }

  private handleContextClose(): void {
    if (!this.closing) console.warn("CloakBrowser context closed unexpectedly; it will relaunch on the next request");
    this.context = null;
    this.rejectQueue(unavailable("Browser is disconnected"));
  }
}

export const browserService = new BrowserService();
