import assert from "node:assert/strict";
import { test } from "node:test";
import type { BrowserContext, Page } from "playwright-core";
import { BrowserSession, normalizeKey, type BrowserStep } from "../src/services/browser-session";

const EMPTY_PAGE_SNAPSHOT = "(page has no readable or interactive content)";

interface FakePageOptions {
  gotoError?: Error;
  /** Full override, used by the queue test to observe how many navigations overlap. */
  goto?: () => Promise<void>;
  /** Receives the same arguments as `page.evaluate`, so a test can tell the collector from the shim. */
  evaluate?: (pageFunction?: unknown) => Promise<unknown>;
  html?: string;
}

/** Minimal stand-in for the agent page; only the calls the session actually makes are implemented. */
function createFakePage(options: FakePageOptions = {}): Page {
  const page = {
    isClosed: () => false,
    url: () => "https://example.com/",
    title: async () => "Example",
    context: () => ({ pages: () => [page] }) as unknown as BrowserContext,
    // The page doubles as its own frame: collection runs through `frame.evaluate`.
    frames: () => [page],
    mainFrame: () => page,
    addInitScript: async () => undefined,
    goto: async () => {
      if (options.goto !== undefined) {
        await options.goto();
        return null;
      }
      if (options.gotoError !== undefined) throw options.gotoError;
      return null;
    },
    waitForLoadState: async () => undefined,
    waitForTimeout: async () => undefined,
    content: async () => options.html ?? "<html><body><p>empty</p></body></html>",
    evaluate: options.evaluate ?? (async () => []),
    close: async () => undefined,
  };
  return page as unknown as Page;
}

function step(action: BrowserStep["action"], extra: Partial<BrowserStep> = {}): BrowserStep {
  return { action, ...extra };
}

test("run reports page metadata and a snapshot for a snapshot step", async () => {
  const session = new BrowserSession(async () => createFakePage());
  const result = await session.run({ steps: [step("snapshot")], snapshot: true });
  assert.equal(result.ok, true);
  assert.equal(result.action, "snapshot");
  assert.equal(result.url, "https://example.com/");
  assert.equal(result.title, "Example");
  assert.equal(result.snapshot, EMPTY_PAGE_SNAPSHOT);
  assert.equal(result.error, "");
  assert.equal(result.screenshotPath, "");
});

test("run skips the snapshot when the caller did not ask for one", async () => {
  let collected = 0;
  // The `__name` shim is installed with a string evaluate; only a function call is a collection.
  const page = createFakePage({ evaluate: async (pageFunction) => { if (typeof pageFunction === "function") collected += 1; return []; } });
  const session = new BrowserSession(async () => page);
  const result = await session.run({ steps: [step("goto", { url: "https://example.com" })], snapshot: false });
  assert.equal(result.ok, true);
  assert.equal(result.snapshot, "");
  assert.equal(collected, 0);
});

test("run names the failing step, keeps the reason, and still returns a snapshot", async () => {
  const failure = new Error("net::ERR_NAME_NOT_RESOLVED");
  const session = new BrowserSession(async () => createFakePage({ gotoError: failure }));
  const result = await session.run({ steps: [step("goto", { url: "https://nope.invalid" })], snapshot: false });
  assert.equal(result.ok, false);
  assert.equal(result.action, "goto");
  assert.ok(result.error.includes("goto failed"));
  assert.ok(result.error.includes("net::ERR_NAME_NOT_RESOLVED"));
  assert.equal(result.snapshot, EMPTY_PAGE_SNAPSHOT);
});

test("run rejects a non-http url as a step failure instead of a crash", async () => {
  const session = new BrowserSession(async () => createFakePage());
  const result = await session.run({ steps: [step("goto", { url: "file:///etc/passwd" })], snapshot: false });
  assert.equal(result.ok, false);
  assert.ok(result.error.includes("http"));
});

test("run stops the batch at the first failing step", async () => {
  const session = new BrowserSession(async () => createFakePage({ gotoError: new Error("boom") }));
  const result = await session.run({
    steps: [step("snapshot"), step("goto", { url: "https://example.com" }), step("press", { key: "Escape" })],
    snapshot: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.action, "goto");
});

test("run serializes concurrent requests over the shared page", async () => {
  let running = 0;
  let peak = 0;
  const page = createFakePage({
    goto: async () => {
      running += 1;
      peak = Math.max(peak, running);
      await new Promise<void>((resolve) => setTimeout(resolve, 5));
      running -= 1;
    },
  });
  const session = new BrowserSession(async () => page);
  const requests = [1, 2, 3].map(() => session.run({ steps: [step("goto", { url: "https://example.com" })], snapshot: false }));
  const results = await Promise.all(requests);
  // Interleaved requests would share one page and step on each other's refs; the queue keeps them apart.
  assert.equal(peak, 1);
  assert.ok(results.every((result) => result.ok));
});

test("run truncates a Playwright call log out of the error message", async () => {
  const failure = new Error("element is not visible\nCall log:\n  - waiting for locator(\"a\")");
  const session = new BrowserSession(async () => createFakePage({ gotoError: failure }));
  const result = await session.run({ steps: [step("goto", { url: "https://example.com" })], snapshot: false });
  assert.equal(result.error, "goto failed: element is not visible");
});

test("normalizeKey speaks the key names a model and a user write", () => {
  assert.equal(normalizeKey("Alt+Left"), "Alt+ArrowLeft");
  assert.equal(normalizeKey("Ctrl+R"), "Control+R");
  assert.equal(normalizeKey("ctrl+shift+tab"), "Control+Shift+Tab");
  assert.equal(normalizeKey("Esc"), "Escape");
  assert.equal(normalizeKey("Return"), "Enter");
  assert.equal(normalizeKey("Cmd+K"), "Meta+K");
  assert.equal(normalizeKey("f5"), "F5");
  assert.equal(normalizeKey("Enter"), "Enter");
  assert.equal(normalizeKey("a"), "a");
  assert.equal(normalizeKey("+"), "+");
  assert.equal(normalizeKey("  "), "");
});

test("run returns the page text for a markdown step", async () => {
  const page = createFakePage({
    html: "<html><head><title>Doc</title></head><body><article><h1>Heading</h1><p>readable body text that is long enough to keep</p></article></body></html>",
  });
  const session = new BrowserSession(async () => page);
  const result = await session.run({ steps: [step("markdown")], snapshot: false });
  assert.equal(result.ok, true);
  assert.ok(result.markdown.includes("readable body text"));
  assert.equal(result.snapshot, "");
});

test("run reports an empty markdown instead of failing when nothing was read", async () => {
  const session = new BrowserSession(async () => createFakePage());
  const result = await session.run({ steps: [step("goto", { url: "https://example.com" })], snapshot: false });
  assert.equal(result.markdown, "");
});
