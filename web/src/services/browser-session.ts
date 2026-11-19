import type { ElementHandle, Frame, Locator, Page } from "playwright-core";
import { NAVIGATION_TIMEOUT_MS, REQUEST_TIMEOUT_MS } from "../config";
import { errorMessage, isErrorNamed, parseHttpUrl as tryParseHttpUrl } from "../utils";
import { browserService, PAGE_SETTLE_TIMEOUT_MS } from "./browser-service";
import { collectInteractiveCandidates, elementForRef, refFrame, refIndex, selectCandidates, type InteractiveCandidate } from "./interactive";
import { extractPageContent } from "./page-content";
import { captureScreenshot } from "./screenshot-service";
import { formatSnapshot } from "./snapshot";

/** Supported mutations. Navigation and observation use separate operations. */
export const BROWSER_STEP_ACTIONS = ["click", "type", "press", "hover", "select", "scroll", "back", "forward", "reload"] as const;
export type BrowserStepAction = (typeof BROWSER_STEP_ACTIONS)[number];
export const BROWSER_OBSERVE_MODES = ["elements", "markdown", "screenshot"] as const;
export type BrowserObserveMode = (typeof BROWSER_OBSERVE_MODES)[number];

export interface BrowserStep {
  action: BrowserStepAction;
  /** Handle printed by a previous snapshot, e.g. `e12`. */
  ref?: string;
  /** Playwright selector; used when `ref` is absent. */
  selector?: string;
  text?: string;
  key?: string;
  value?: string;
  direction?: "up" | "down";
}

export interface BrowserResult {
  ok: boolean;
  url: string;
  title: string;
  error: string;
  snapshot: string;
  /** Readable Markdown of the live page; only a `markdown` step fills it. */
  markdown: string;
  screenshotPath: string;
  screenshotError: string;
}

const DEFAULT_STEP_TIMEOUT_MS = 10_000;
const MAX_ERROR_CHARS = 1_000;
/** Keeps the reply ahead of the HTTP request timeout, so the agent gets the reason instead of a 504. */
const BUDGET_MARGIN_MS = 5_000;
const MIN_BUDGET_MS = 2_000;
/** A capture that lands mid-document is retried once after the page settles. */
const SNAPSHOT_ATTEMPTS = 2;
const SNAPSHOT_RETRY_DELAY_MS = 300;

type ActionTarget = ElementHandle<Element> | Locator;

/** Maps common key names to Playwright names. */
const KEY_ALIASES: Readonly<Record<string, string>> = {
  ctrl: "Control",
  control: "Control",
  cmd: "Meta",
  command: "Meta",
  meta: "Meta",
  super: "Meta",
  win: "Meta",
  alt: "Alt",
  option: "Alt",
  opt: "Alt",
  shift: "Shift",
  esc: "Escape",
  escape: "Escape",
  return: "Enter",
  enter: "Enter",
  tab: "Tab",
  space: "Space",
  spacebar: "Space",
  backspace: "Backspace",
  del: "Delete",
  delete: "Delete",
  ins: "Insert",
  left: "ArrowLeft",
  right: "ArrowRight",
  up: "ArrowUp",
  down: "ArrowDown",
  pageup: "PageUp",
  pagedown: "PageDown",
  home: "Home",
  end: "End",
};

/** Translates `Alt+Left` into `Alt+ArrowLeft`; unknown parts are passed through untouched. */
export function normalizeKey(raw: string): string {
  const parts = raw.split("+").map((part) => part.trim()).filter((part) => part !== "");
  if (parts.length === 0) return raw.trim();
  const lastIndex = parts.length - 1;
  return parts
    .map((part, index) => {
      const alias = KEY_ALIASES[part.toLowerCase()];
      if (alias !== undefined) return alias;
      // Function keys are spelled `F5`, not `f5`.
      return index === lastIndex && /^f\d{1,2}$/i.test(part) ? part.toUpperCase() : part;
    })
    .join("+");
}

export class BrowserSession {
  private page: Page | null = null;
  private queue: Promise<void> = Promise.resolve();
  /** Ref prefix -> frame, refreshed by every snapshot so a `f2e12` ref can be resolved. */
  private frames: Map<string, Frame> = new Map();
  /** Prefix per frame, assigned on first sight: a frame arriving or leaving must not rename the others. */
  private readonly framePrefixes: WeakMap<Frame, string> = new WeakMap();
  private nextFramePrefix = 1;
  private readonly openPage: () => Promise<Page>;

  constructor(openPage: () => Promise<Page> = () => browserService.openPage()) {
    this.openPage = openPage;
  }

  /** Opens one URL on the shared page. Reading the result is an explicit observe operation. */
  open(url: string): Promise<BrowserResult> {
    return this.enqueue(async (page) => {
      let error = "";
      try {
        await this.goto(page, url, NAVIGATION_TIMEOUT_MS);
      } catch (failure) {
        error = describeFailure("open", failure);
      }
      return this.result(page, error);
    });
  }

  /** Reads one representation of the current page without changing it. */
  observe(mode: BrowserObserveMode, screenshotPath?: string): Promise<BrowserResult> {
    return this.enqueue(async (page) => {
      const snapshot = mode === "elements" ? await this.takeSnapshot(page) : "";
      const markdown = mode === "markdown" ? (await extractPageContent(page)).content : "";
      const screenshot = await captureScreenshot(page, screenshotPath);
      return this.result(page, "", snapshot, markdown, screenshot);
    });
  }

  /** Runs mutations and captures the final state. */
  act(steps: readonly BrowserStep[], screenshotPath: string): Promise<BrowserResult> {
    return this.enqueue((page) => this.runSteps(page, steps, screenshotPath));
  }

  /** Operations share one page, so a second request must not interleave. */
  private enqueue(operation: (page: Page) => Promise<BrowserResult>): Promise<BrowserResult> {
    const task = this.queue.then(async () => operation(await this.currentPage()));
    // The queue only needs the settled state; the result (and the failure) travel through `task`.
    this.queue = task.then(() => undefined, () => undefined);
    return task;
  }

  /** Closes the agent page; the browser itself stays alive for `/fetch` and `/search`. */
  async close(): Promise<void> {
    const page = this.page;
    this.page = null;
    if (page === null) return;
    try {
      await page.close();
    } catch (error) {
      console.error("Browser page close failed", error);
    }
  }

  private async currentPage(): Promise<Page> {
    if (this.page !== null && !this.page.isClosed()) return this.page;
    const page = await this.openPage();
    await installNameHelper(page);
    this.page = page;
    return page;
  }

  private async runSteps(page: Page, steps: readonly BrowserStep[], screenshotPath: string): Promise<BrowserResult> {
    const deadline = Date.now() + REQUEST_TIMEOUT_MS - BUDGET_MARGIN_MS;
    let error = "";
    for (const step of steps) {
      const remaining = deadline - Date.now();
      if (remaining < MIN_BUDGET_MS) {
        error = `the request ran out of time before: ${step.action}`;
        break;
      }
      try {
        await this.applyStep(page, step, Math.min(remaining, DEFAULT_STEP_TIMEOUT_MS));
        page = await this.currentPage();
      } catch (failure) {
        error = describeFailure(step.action, failure);
        break;
      }
    }

    // A click may promote a newly opened tab to the shared page. Report and capture that final page,
    // not the page on which the batch started.
    const screenshot = await captureScreenshot(page, screenshotPath);
    return this.result(page, error, "", "", screenshot);
  }

  private async result(
    page: Page,
    error: string,
    snapshot = "",
    markdown = "",
    screenshot = { screenshotPath: "", screenshotError: "" },
  ): Promise<BrowserResult> {
    return {
      ok: error === "",
      url: page.url(),
      title: await page.title().catch(() => ""),
      error,
      snapshot,
      markdown,
      ...screenshot,
    };
  }

  private async applyStep(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    switch (step.action) {
      case "click":
        await this.click(page, step, timeout);
        return;
      case "type":
        await this.withTarget(page, step, (target) => target.fill(step.text ?? "", { timeout }));
        return;
      case "press":
        await this.press(page, step, timeout);
        return;
      case "hover":
        await this.withTarget(page, step, (target) => target.hover({ timeout }));
        return;
      case "select":
        await this.withTarget(page, step, (target) => target.selectOption(step.value ?? "", { timeout }));
        return;
      case "scroll":
        await this.scroll(page, step, timeout);
        return;
      case "back":
        await page.goBack({ waitUntil: "domcontentloaded", timeout });
        return;
      case "forward":
        await page.goForward({ waitUntil: "domcontentloaded", timeout });
        return;
      case "reload":
        await page.reload({ waitUntil: "domcontentloaded", timeout });
        return;
    }
  }

  private async goto(page: Page, rawUrl: string, timeout: number): Promise<void> {
    const url = parseHttpUrl(rawUrl);
    await page.goto(url, { waitUntil: "domcontentloaded", timeout });
    // `load` is best effort: a chatty page keeps requests open forever and must not fail the step.
    await page.waitForLoadState("load", { timeout: Math.min(timeout, PAGE_SETTLE_TIMEOUT_MS) }).catch(() => undefined);
  }

  /** Clicks the target and follows a popup (`target=_blank`) the click opened. */
  private async click(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    const before = new Set(page.context().pages());
    await this.withTarget(page, step, (target) => target.click({ timeout }));
    const popup = page.context().pages().find((candidate) => candidate !== page && !before.has(candidate));
    if (popup === undefined || popup.isClosed()) return;
    await popup.waitForLoadState("domcontentloaded", { timeout: PAGE_SETTLE_TIMEOUT_MS }).catch(() => undefined);
    await installNameHelper(popup);
    this.page = popup;
    await page.close().catch((error: unknown) => console.error("Previous browser page close failed", error));
  }

  private async press(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    const key = normalizeKey(step.key ?? "");
    if (key === "") throw new Error("press needs a key, for example Enter, Escape, or Alt+Left");
    if (step.ref === undefined && step.selector === undefined) {
      await page.keyboard.press(key);
      return;
    }
    await this.withTarget(page, step, (target) => target.press(key, { timeout }));
  }

  /** One viewport per step: the model cannot know pixel sizes, and a viewport is what it sees. */
  private async scroll(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    if (step.ref !== undefined || step.selector !== undefined) {
      await this.withTarget(page, step, (target) => target.scrollIntoViewIfNeeded({ timeout }));
      return;
    }
    await page.evaluate((up: boolean) => {
      // 0.9 keeps the last line of the previous screen visible, so nothing is skipped unseen.
      window.scrollBy(0, (up ? -1 : 1) * window.innerHeight * 0.9);
    }, step.direction === "up");
  }

  /** Runs against a target and releases ref handles afterward. */
  private async withTarget<T>(page: Page, step: BrowserStep, run: (target: ActionTarget) => Promise<T>): Promise<T> {
    const target = await this.resolveTarget(page, step);
    try {
      return await run(target);
    } finally {
      await releaseTarget(target);
    }
  }

  /** Resolves a ref handle or a selector into something clickable. */
  private async resolveTarget(page: Page, step: BrowserStep): Promise<ActionTarget> {
    if (step.ref !== undefined) {
      const ref = step.ref;
      const frame = this.frameFor(page, ref);
      if (frame === null) throw new Error(`ref ${ref} is stale: that frame is gone, take a new snapshot first`);
      const handle = await frame.evaluateHandle(elementForRef, refIndex(ref));
      const element = handle.asElement();
      if (element === null) {
        await handle.dispose().catch(() => undefined);
        throw new Error(`ref ${ref} is stale: the page changed since the last snapshot, take a new snapshot first`);
      }
      return element;
    }
    const selector = (step.selector ?? "").trim();
    if (selector === "") throw new Error("the step needs a ref from the last snapshot, or a CSS selector");
    const locator = page.locator(selector).first();
    if ((await locator.count()) === 0) throw new Error(`no element matches selector: ${selector}`);
    return locator;
  }

  /** An unprefixed ref lives in the main frame; `f2`-style refs name a frame the last snapshot saw. */
  private frameFor(page: Page, ref: string): Frame | null {
    const prefix = refFrame(ref);
    return prefix === "" ? page.mainFrame() : this.frames.get(prefix) ?? null;
  }

  /** The main frame stays unprefixed (`e12`); other frames are numbered in the order they are seen. */
  private prefixFor(page: Page, frame: Frame): string {
    const known = this.framePrefixes.get(frame);
    if (known !== undefined) return known;
    const prefix = frame === page.mainFrame() ? "" : `f${this.nextFramePrefix}`;
    if (prefix !== "") this.nextFramePrefix += 1;
    this.framePrefixes.set(frame, prefix);
    return prefix;
  }

  /** Collects a snapshot, retrying once when the page is still loading. */
  private async takeSnapshot(page: Page): Promise<string> {
    // A step that navigated may still be parsing; waiting here is what replaces a model-driven `wait`.
    await waitForDocument(page);
    let candidates: InteractiveCandidate[] = [];
    for (let attempt = 0; attempt < SNAPSHOT_ATTEMPTS; attempt += 1) {
      // An empty result usually means the document is still parsing or about to be replaced.
      if (attempt > 0) await page.waitForTimeout(SNAPSHOT_RETRY_DELAY_MS);
      candidates = await this.collectCandidates(page);
      if (candidates.some((candidate) => candidate.rendered)) break;
    }
    return formatSnapshot(selectCandidates(candidates));
  }

  /** Collects interactive elements from every frame. */
  private async collectCandidates(page: Page): Promise<InteractiveCandidate[]> {
    this.frames.clear();
    const candidates: InteractiveCandidate[] = [];
    for (const frame of page.frames()) {
      const prefix = this.prefixFor(page, frame);
      this.frames.set(prefix, frame);
      try {
        candidates.push(...(await frame.evaluate(collectInteractiveCandidates, prefix)));
      } catch (error) {
        // A frame that navigated mid-capture is skipped; the next snapshot picks it up again.
        console.error("Browser frame collection failed", error);
      }
    }
    return candidates;
  }
}

export const browserSession = new BrowserSession();

/** Page-side shim required by esbuild's `keepNames` transform. */
const NAME_HELPER = "globalThis.__name = globalThis.__name || ((target) => target)";

/** Installs the shim in the current document and future navigations. */
async function installNameHelper(page: Page): Promise<void> {
  await page.addInitScript(NAME_HELPER);
  await page.evaluate(NAME_HELPER);
}

/** Waits for a document that is still loading, so the next capture reads real content. */
async function waitForDocument(page: Page): Promise<void> {
  await page.waitForLoadState("domcontentloaded", { timeout: PAGE_SETTLE_TIMEOUT_MS }).catch(() => undefined);
}

/** Releases ref handles; locators need no cleanup. */
async function releaseTarget(target: ActionTarget): Promise<void> {
  if (!("dispose" in target)) return;
  await target.dispose().catch(() => undefined);
}

function parseHttpUrl(raw: string): string {
  const url = tryParseHttpUrl(raw);
  if (url === null) throw new Error(`url must be an absolute http or https URL, got: ${raw}`);
  return url.href;
}

/** Playwright appends a call log full of noise; the first line is the part the model can act on. */
function describeFailure(action: string, failure: unknown): string {
  const message = errorMessage(failure);
  const reason = message.split("\nCall log:")[0]?.trim() ?? message;
  const timeout = isErrorNamed(failure, "TimeoutError") ? "timeout: " : "";
  const text = `${action} failed: ${timeout}${reason}`;
  return text.length > MAX_ERROR_CHARS ? `${text.slice(0, MAX_ERROR_CHARS)}…` : text;
}
