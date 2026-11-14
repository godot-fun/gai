import type { ElementHandle, Frame, Locator, Page } from "playwright-core";
import { config } from "../config";
import { browserService } from "./browser-service";
import { collectInteractiveCandidates, refFrame, refIndex, selectCandidates, type InteractiveCandidate } from "./interactive";
import { extractPageContent } from "./page-content";
import { captureScreenshot } from "./screenshot-service";
import { formatSnapshot } from "./snapshot";

/**
 * Long-lived page the agent drives step by step.
 *
 * `BrowserService.openPage` hands out short-lived pages to `/fetch` and `/search`; browser control
 * needs the opposite: one page keeping its scroll position, login session, and element handles
 * across many requests. Refs are therefore stored inside the page (`window.__gaiBrowserRefs`) and
 * only survive while that document lives — a navigation invalidates them, which the next action
 * reports as a stale ref instead of silently clicking the wrong element.
 */

/**
 * Steps a request may contain; the route rejects anything else before a page is touched.
 *
 * `back`, `forward`, and `reload` are steps rather than `press` shortcuts on purpose: synthetic key
 * events only reach the content process, so `Alt+Left` / `Ctrl+R` / `F5` never trigger Firefox's
 * browser-level history or reload (verified against Camoufox). Waiting has no action at all — the
 * session settles the document before it reads the DOM. `markdown` is an action rather than a
 * request flag so a batch can act and then read the page it produced.
 */
export const BROWSER_STEP_ACTIONS = ["goto", "snapshot", "markdown", "click", "type", "press", "hover", "select", "scroll", "back", "forward", "reload"] as const;
export type BrowserStepAction = (typeof BROWSER_STEP_ACTIONS)[number];

export interface BrowserStep {
  action: BrowserStepAction;
  url?: string;
  /** Handle printed by a previous snapshot, e.g. `e12`. */
  ref?: string;
  /** Playwright selector; used when `ref` is absent. */
  selector?: string;
  text?: string;
  key?: string;
  value?: string;
  direction?: "up" | "down";
}

export interface BrowserRequest {
  steps: readonly BrowserStep[];
  /** Whether the reply carries a fresh snapshot; a failed step reports one regardless. */
  snapshot: boolean;
  screenshotPath?: string;
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
const SETTLE_TIMEOUT_MS = 5_000;
const MAX_ERROR_CHARS = 1_000;
/** Keeps the reply ahead of the HTTP request timeout, so the agent gets the reason instead of a 504. */
const BUDGET_MARGIN_MS = 5_000;
const MIN_BUDGET_MS = 2_000;
/** A capture that lands mid-document is retried once after the page settles. */
const SNAPSHOT_ATTEMPTS = 2;
const SNAPSHOT_RETRY_DELAY_MS = 300;

type ActionTarget = ElementHandle<Element> | Locator;

/**
 * Key aliases a browser user would write. Playwright wants `Alt+ArrowLeft` and `Control+R`, while a
 * model (like a person) writes `Alt+Left` and `Ctrl+R`, so the session translates before pressing.
 */
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

/** A step the browser could not perform; the message is forwarded to the model as-is. */
class BrowserStepError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BrowserStepError";
  }
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

  /** Serialized entry point: steps share one page, so a second request must not interleave. */
  run(request: BrowserRequest): Promise<BrowserResult> {
    const task = this.queue.then(() => this.runSteps(request));
    this.queue = task.then(ignore, ignore);
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

  private async runSteps(request: BrowserRequest): Promise<BrowserResult> {
    const page = await this.currentPage();
    const deadline = Date.now() + Math.max(MIN_BUDGET_MS, config.requestTimeoutMs - BUDGET_MARGIN_MS);
    let error = "";
    let markdown = "";
    for (const step of request.steps) {
      const remaining = deadline - Date.now();
      if (remaining < MIN_BUDGET_MS) {
        error = `the request ran out of time before: ${step.action}`;
        break;
      }
      try {
        const text = await this.applyStep(page, step, Math.min(remaining, stepTimeout(step)));
        if (text !== "") markdown = text;
      } catch (failure) {
        error = describeFailure(step.action, failure);
        break;
      }
    }

    // A snapshot after a failure is what lets the model correct itself instead of retrying blind.
    const snapshot = request.snapshot || error !== "" ? await this.takeSnapshot(page) : "";
    const screenshot = await captureScreenshot(page, request.screenshotPath);
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

  /** Runs one step and returns the page text when the step read the page, otherwise an empty string. */
  private async applyStep(page: Page, step: BrowserStep, timeout: number): Promise<string> {
    switch (step.action) {
      case "goto":
        await this.goto(page, step, timeout);
        return "";
      case "snapshot":
        return "";
      case "markdown":
        return (await extractPageContent(page)).content;
      case "click":
        await this.click(page, step, timeout);
        return "";
      case "type":
        await this.withTarget(page, step, (target) => target.fill(step.text ?? "", { timeout }));
        return "";
      case "press":
        await this.press(page, step, timeout);
        return "";
      case "hover":
        await this.withTarget(page, step, (target) => target.hover({ timeout }));
        return "";
      case "select":
        await this.withTarget(page, step, (target) => target.selectOption(step.value ?? "", { timeout }));
        return "";
      case "scroll":
        await this.scroll(page, step, timeout);
        return "";
      case "back":
        await page.goBack({ waitUntil: "domcontentloaded", timeout });
        return "";
      case "forward":
        await page.goForward({ waitUntil: "domcontentloaded", timeout });
        return "";
      case "reload":
        await page.reload({ waitUntil: "domcontentloaded", timeout });
        return "";
    }
  }

  private async goto(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    const url = parseHttpUrl(step.url ?? "");
    await page.goto(url, { waitUntil: "domcontentloaded", timeout });
    // `load` is best effort: a chatty page keeps requests open forever and must not fail the step.
    await page.waitForLoadState("load", { timeout: Math.min(timeout, SETTLE_TIMEOUT_MS) }).catch(() => undefined);
  }

  /** Clicks the target and follows a popup (`target=_blank`) the click opened. */
  private async click(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    const before = new Set(page.context().pages());
    await this.withTarget(page, step, (target) => target.click({ timeout }));
    const popup = page.context().pages().find((candidate) => candidate !== page && !before.has(candidate));
    if (popup === undefined || popup.isClosed()) return;
    await popup.waitForLoadState("domcontentloaded", { timeout: SETTLE_TIMEOUT_MS }).catch(() => undefined);
    await installNameHelper(popup);
    this.page = popup;
  }

  private async press(page: Page, step: BrowserStep, timeout: number): Promise<void> {
    const raw = (step.key ?? "").trim();
    if (raw === "") throw new BrowserStepError("press needs a key, for example Enter, Escape, or Alt+Left");
    const key = normalizeKey(raw);
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

  /**
   * Resolves the target of a targeted step, runs one action on it, and releases what the lookup
   * minted: a `ref` becomes an `ElementHandle`, and the page keeps every handle alive until it is
   * disposed — an agent page lives across many requests, so un-disposed handles pile up.
   */
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
      const frame = this.frames.get(refFrame(step.ref)) ?? (refFrame(step.ref) === "" ? page.mainFrame() : null);
      if (frame === null) {
        throw new BrowserStepError(`ref ${step.ref} is stale: that frame is gone, take a new snapshot first`);
      }
      const index = refIndex(step.ref);
      const handle = await frame.evaluateHandle((wanted: number) => {
        const store = window as unknown as { __gaiBrowserRefs?: Element[] };
        const elements = store.__gaiBrowserRefs;
        if (!Array.isArray(elements)) return null;
        const element = elements[wanted];
        return element !== undefined && element.isConnected ? element : null;
      }, index);
      const element = handle.asElement();
      if (element === null) {
        throw new BrowserStepError(`ref ${step.ref} is stale: the page changed since the last snapshot, take a new snapshot first`);
      }
      return element;
    }
    const selector = (step.selector ?? "").trim();
    if (selector === "") throw new BrowserStepError("the step needs a ref from the last snapshot, or a CSS selector");
    const locator = page.locator(selector).first();
    if ((await locator.count()) === 0) throw new BrowserStepError(`no element matches selector: ${selector}`);
    return locator;
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

  /** Collects a snapshot; a failed collection still leaves the page metadata in the reply. */
  private async takeSnapshot(page: Page): Promise<string> {
    // A step that navigated may still be parsing; waiting here is what replaces a model-driven `wait`.
    await waitForDocument(page);
    let candidates: InteractiveCandidate[] = [];
    for (let attempt = 0; attempt < SNAPSHOT_ATTEMPTS; attempt += 1) {
      candidates = await this.collectCandidates(page);
      if (candidates.some((candidate) => candidate.rendered)) break;
      // An empty result usually means the document is still parsing or about to be replaced.
      await page.waitForTimeout(SNAPSHOT_RETRY_DELAY_MS);
    }
    return formatSnapshot(selectCandidates(candidates));
  }

  /**
   * Every interactable element of every frame, unfiltered. Recalls what the DOM offers instead of
   * guessing from a tree walk, so shadow roots and cross-frame widgets are not silently lost.
   */
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

/** esbuild's `keepNames` helper, as a string so esbuild cannot name-wrap the shim itself. */
const NAME_HELPER = "globalThis.__name = globalThis.__name || ((target) => target)";

/**
 * `tsx` compiles with esbuild's `keepNames`, which wraps every named function in the evaluated body
 * as `__name(fn, "fn")`. That helper lives in the module, not in the page, so the page needs a
 * no-op stand-in. An init script covers every later navigation and child frame; the immediate
 * evaluate covers the document that is already loaded. Called once per page, not per snapshot.
 */
async function installNameHelper(page: Page): Promise<void> {
  await page.addInitScript(NAME_HELPER);
  await page.evaluate(NAME_HELPER);
}

/** Waits for a document that is still loading, so the next capture reads real content. */
async function waitForDocument(page: Page): Promise<void> {
  await page.waitForLoadState("domcontentloaded", { timeout: SETTLE_TIMEOUT_MS }).catch(() => undefined);
}

/** Releases the handle a `ref` resolved to; a selector resolves to a `Locator`, which has nothing to release. */
async function releaseTarget(target: ActionTarget): Promise<void> {
  const handle = target as ElementHandle<Element>;
  if (typeof handle.dispose !== "function") return;
  await handle.dispose().catch(() => undefined);
}

function parseHttpUrl(raw: string): string {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    throw new BrowserStepError(`url must be an absolute URL, got: ${raw}`);
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") throw new BrowserStepError(`url must be http or https, got: ${raw}`);
  return url.href;
}

function stepTimeout(step: BrowserStep): number {
  return step.action === "goto" ? config.navigationTimeoutMs : DEFAULT_STEP_TIMEOUT_MS;
}

/** Playwright appends a call log full of noise; the first line is the part the model can act on. */
function describeFailure(action: string, failure: unknown): string {
  const message = failure instanceof Error ? failure.message : String(failure);
  const reason = message.split("\nCall log:")[0]?.trim() ?? message;
  const timeout = failure instanceof Error && failure.name === "TimeoutError" ? "timeout: " : "";
  const text = `${action} failed: ${timeout}${reason}`;
  return text.length > MAX_ERROR_CHARS ? `${text.slice(0, MAX_ERROR_CHARS)}…` : text;
}

function ignore(): void {
  // Queue links only need the settled state; the result travels through the promise returned to the caller.
}
