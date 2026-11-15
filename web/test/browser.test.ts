import assert from "node:assert/strict";
import { mkdtemp, rm, stat } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { baseUrl, client } from "./server-client";

interface BrowserBody {
  ok: boolean;
  url: string;
  title: string;
  error: string;
  snapshot: string;
  markdown: string;
  screenshotPath: string;
  screenshotError: string;
}

async function open(url: string): Promise<BrowserBody> {
  const response = await client.post(`${baseUrl}/browser/open`, { url });
  assert.equal(response.status, 200);
  return response.data as BrowserBody;
}

async function observe(mode: "elements" | "markdown" | "screenshot", screenshotPath?: string): Promise<BrowserBody> {
  const response = await client.post(`${baseUrl}/browser/observe`, { mode, screenshotPath });
  assert.equal(response.status, 200);
  return response.data as BrowserBody;
}

async function act(steps: unknown[], screenshotPath: string): Promise<BrowserBody> {
  const response = await client.post(`${baseUrl}/browser/action`, { steps, screenshotPath });
  assert.equal(response.status, 200);
  return response.data as BrowserBody;
}

test("open navigates and observe elements returns refs", async () => {
  const opened = await open("https://example.com/");
  assert.equal(opened.ok, true);
  assert.equal(opened.url, "https://example.com/");
  assert.equal(opened.snapshot, "");

  const observed = await observe("elements");
  assert.match(observed.snapshot, /^- link "Learn more" \[e\d+\]$/m);
  assert.equal(observed.markdown, "");
});

test("action clicks an observed ref and always captures a screenshot", async () => {
  await open("https://example.com/");
  const observed = await observe("elements");
  const ref = /\[(e\d+)\]/.exec(observed.snapshot)?.[1] ?? "";
  assert.notEqual(ref, "");

  const directory = await mkdtemp(path.join(os.tmpdir(), "gai-browser-"));
  const screenshotPath = path.join(directory, "action.png");
  try {
    const result = await act([{ action: "click", ref }], screenshotPath);
    assert.equal(result.ok, true);
    assert.ok(result.url.startsWith("https://www.iana.org/"));
    assert.equal(result.snapshot, "");
    assert.equal(result.screenshotPath, screenshotPath);
    assert.ok((await stat(screenshotPath)).size > 0);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("action reports a stale ref without returning a snapshot", async () => {
  await open("https://example.com/");
  const directory = await mkdtemp(path.join(os.tmpdir(), "gai-browser-"));
  try {
    const result = await act([{ action: "click", ref: "e999" }], path.join(directory, "failed.png"));
    assert.equal(result.ok, false);
    assert.ok(result.error.includes("e999"));
    assert.equal(result.snapshot, "");
    assert.notEqual(result.screenshotPath, "");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("observe supports markdown and screenshot modes", async () => {
  await open("https://example.com/");
  const markdown = await observe("markdown");
  assert.ok(markdown.markdown.includes("documentation examples"));
  assert.equal(markdown.snapshot, "");

  const directory = await mkdtemp(path.join(os.tmpdir(), "gai-browser-"));
  const screenshotPath = path.join(directory, "observe.png");
  try {
    const screenshot = await observe("screenshot", screenshotPath);
    assert.equal(screenshot.screenshotPath, screenshotPath);
    assert.ok((await stat(screenshotPath)).size > 0);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("browser endpoints reject malformed requests before touching the page", async () => {
  const unknownAction = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "eval" }], screenshotPath: "C:/tmp/a.png" }, { validateStatus: () => true });
  assert.equal(unknownAction.status, 400);
  assert.equal(unknownAction.data.error.code, "INVALID_ACTION");

  const noScreenshot = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "reload" }] }, { validateStatus: () => true });
  assert.equal(noScreenshot.status, 400);

  const gotoAction = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "goto", url: "https://example.com" }], screenshotPath: "C:/tmp/a.png" }, { validateStatus: () => true });
  assert.equal(gotoAction.status, 400);
  assert.equal(gotoAction.data.error.code, "INVALID_ACTION");

  const badMode = await client.post(`${baseUrl}/browser/observe`, { mode: "dom" }, { validateStatus: () => true });
  assert.equal(badMode.status, 400);

  const screenshotWithoutPath = await client.post(`${baseUrl}/browser/observe`, { mode: "screenshot" }, { validateStatus: () => true });
  assert.equal(screenshotWithoutPath.status, 400);
});

test("action validates fields belonging to each action", async () => {
  const screenshotPath = path.join(os.tmpdir(), `gai-browser-${Date.now()}.png`);
  const ignored = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "click", ref: "e999", direction: "left" }], screenshotPath }, { validateStatus: () => true });
  assert.equal(ignored.status, 200);
  assert.equal(ignored.data.error.includes("direction"), false);

  const rejected = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "scroll", direction: "left" }], screenshotPath }, { validateStatus: () => true });
  assert.equal(rejected.status, 400);
  assert.ok(rejected.data.error.message.includes("direction"));
  await rm(screenshotPath, { force: true });
});
