import { config } from "../config";
import { chromium, BrowserContext, Page } from "playwright";
import { HttpError, HttpStatus } from "../http";

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

/** One request parked in the slot queue: it either gets the free slot or fails with an error. */
class Waiter {
  private readonly timer: NodeJS.Timeout;
  private readonly resolve: () => void;
  private readonly reject: (error: Error) => void;

  constructor(resolve: () => void, reject: (error: Error) => void, timeoutMs: number, onTimeout: () => void) {
    this.resolve = resolve;
    this.reject = reject;
    // A waiter that never receives a slot must not outlive the HTTP request that created it.
    this.timer = setTimeout(() => {
      onTimeout();
      this.fail(unavailable("Browser is busy"));
    }, timeoutMs);
  }

  /** Receives the released slot and resumes the parked request. */
  wake(): void {
    this.stop();
    this.resolve();
  }

  /** Resumes the parked request with a failure. */
  fail(error: Error): void {
    this.stop();
    this.reject(error);
  }

  private stop(): void {
    clearTimeout(this.timer);
  }
}

export class BrowserService {
  private context: BrowserContext | null = null;
  private starting: Promise<BrowserContext> | null = null;
  private activePages = 0;
  private readonly queue: Waiter[] = [];
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
      console.error("Browser close failed", error);
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
      context = await chromium.launchPersistentContext(config.userDataDir, {
        headless: config.headless,
        proxy: config.proxy ? { server: config.proxy } : undefined,
      });
    } catch (error) {
      console.error("Browser launch failed", error);
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
      // The timed-out waiter removes itself; otherwise a release would hand its slot to a settled request.
      const waiter: Waiter = new Waiter(resolve, reject, config.requestTimeoutMs, () => {
        const index = this.queue.indexOf(waiter);
        if (index >= 0) this.queue.splice(index, 1);
      });
      this.queue.push(waiter);
    });
  }

  [releasePage](): void {
    const next = this.queue.shift();
    if (next !== undefined && this.isReady()) {
      // Hand the slot over without touching the counter.
      next.wake();
      return;
    }
    this.activePages = Math.max(0, this.activePages - 1);
    if (next !== undefined) next.fail(unavailable("Browser is unavailable"));
  }

  private rejectQueue(error: Error): void {
    for (const waiter of this.queue.splice(0)) waiter.fail(error);
  }

  private handleContextClose(): void {
    if (!this.closing) console.warn("Browser context closed unexpectedly; it will relaunch on the next request");
    this.context = null;
    this.rejectQueue(unavailable("Browser is disconnected"));
  }
}

export const browserService = new BrowserService();
