import assert from "node:assert/strict";
import { mkdtemp, rm, stat } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import axios from "axios";
import { loadConfig } from "../src/config";

const config = loadConfig();
const baseUrl = `http://${config.host}:${config.port}`;
// The environment may export HTTP_PROXY for the browser; the local server must be reached directly.
const client = axios.create({ proxy: false });

interface ActionBody {
  ok: boolean;
  url: string;
  title: string;
  error: string;
  snapshot: string;
  markdown: string;
  screenshotPath: string;
  screenshotError: string;
}

async function runAction(steps: unknown[], extra: Record<string, unknown> = {}): Promise<ActionBody> {
  const response = await client.post(`${baseUrl}/browser/action`, { steps, ...extra });
  assert.equal(response.status, 200);
  return response.data as ActionBody;
}

test("POST /browser/action navigates and returns a snapshot with refs", async () => {
  const body = await runAction([{ action: "goto", url: "https://example.com/" }]);
  assert.equal(body.ok, true);
  assert.equal(body.url, "https://example.com/");
  assert.equal(body.title, "Example Domain");
  assert.equal(body.error, "");
  // The elements view lists interactable elements only; prose comes from mode=markdown.
  assert.match(body.snapshot, /^- link "Learn more" \[e\d+\]$/m);
});

test("POST /browser/action clicks a ref from the snapshot and keeps the page", async () => {
  const opened = await runAction([{ action: "goto", url: "https://example.com/" }]);
  const ref = /\[(e\d+)\]/.exec(opened.snapshot)?.[1] ?? "";
  assert.notEqual(ref, "");

  const clicked = await runAction([{ action: "click", ref }]);
  assert.equal(clicked.ok, true);
  assert.ok(clicked.url.startsWith("https://www.iana.org/"));
  assert.notEqual(clicked.snapshot, "");
});

test("POST /browser/action reports a stale ref instead of clicking blind", async () => {
  await runAction([{ action: "goto", url: "https://example.com/" }]);
  const stale = await runAction([{ action: "click", ref: "e999" }]);
  assert.equal(stale.ok, false);
  assert.ok(stale.error.includes("e999"));
  assert.ok(stale.snapshot.includes("Learn more"));
});

test("POST /browser/action captures a screenshot when a path is given", async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "gai-browser-"));
  const screenshotPath = path.join(directory, "page.png");
  try {
    const body = await runAction([{ action: "goto", url: "https://example.com/" }], { screenshotPath });
    assert.equal(body.screenshotPath, screenshotPath);
    assert.equal(body.screenshotError, "");
    assert.ok((await stat(screenshotPath)).size > 0);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("POST /browser/action rejects a malformed request before touching the page", async () => {
  const unknownAction = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "eval", text: "1" }] }, { validateStatus: () => true });
  assert.equal(unknownAction.status, 400);
  assert.equal(unknownAction.data.error.code, "INVALID_ACTION");

  const missingKey = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "press" }] }, { validateStatus: () => true });
  assert.equal(missingKey.status, 400);
  assert.equal(missingKey.data.error.code, "INVALID_REQUEST");

  const noSteps = await client.post(`${baseUrl}/browser/action`, { steps: [] }, { validateStatus: () => true });
  assert.equal(noSteps.status, 400);

  const manySteps = await client.post(`${baseUrl}/browser/action`, { steps: Array.from({ length: 13 }, () => ({ action: "snapshot" })) }, { validateStatus: () => true });
  assert.equal(manySteps.status, 400);
  assert.equal(manySteps.data.error.code, "TOO_MANY_STEPS");
});

test("POST /browser/action goes back and reloads without a key press", async () => {
  await runAction([{ action: "goto", url: "https://example.com/" }]);
  const opened = await runAction([{ action: "goto", url: "https://www.iana.org/help/example-domains" }]);
  assert.equal(opened.url, "https://www.iana.org/help/example-domains");

  // Synthetic key events stop at the content process, so Alt+Left cannot replace this step.
  const back = await runAction([{ action: "back" }], { snapshot: false });
  assert.equal(back.ok, true);
  assert.equal(back.url, "https://example.com/");

  const reload = await runAction([{ action: "reload" }, { action: "forward" }], { snapshot: false });
  assert.equal(reload.ok, true);
  assert.equal(reload.url, "https://www.iana.org/help/example-domains");
});

test("POST /browser/action rejects the removed wait step", async () => {
  const response = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "wait", milliseconds: 500 }] }, { validateStatus: () => true });
  assert.equal(response.status, 400);
  assert.equal(response.data.error.code, "INVALID_ACTION");
});

test("POST /browser/action reads the live page as Markdown", async () => {
  await runAction([{ action: "goto", url: "https://example.com/" }]);
  const observed = await runAction([{ action: "markdown" }], { snapshot: false });
  assert.equal(observed.ok, true);
  assert.ok(observed.markdown.includes("documentation examples"));
  assert.equal(observed.snapshot, "");
});

test("POST /browser/action reports the budget instead of dropping elements silently", async () => {
  await runAction([{ action: "goto", url: "https://en.wikipedia.org/wiki/Godot_(game_engine)" }]);
  const observed = await runAction([{ action: "snapshot" }]);
  assert.equal(observed.ok, true);
  assert.match(observed.snapshot, /^- (banner|navigation|main|form|dialog|page)( ")?/m);
  assert.match(observed.snapshot, /\(\d+ interactive elements over the per-step budget/);
});

test("POST /browser/action drops fields that do not belong to the action", async () => {
  // `direction` only exists for scroll: on a click it is ignored instead of rejected.
  const ignored = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "click", ref: "e999", direction: "left" }] }, { validateStatus: () => true });
  assert.equal(ignored.status, 200);
  assert.equal(ignored.data.error.includes("direction"), false);

  // On scroll it is still validated.
  const rejected = await client.post(`${baseUrl}/browser/action`, { steps: [{ action: "scroll", direction: "left" }] }, { validateStatus: () => true });
  assert.equal(rejected.status, 400);
  assert.ok(rejected.data.error.message.includes("direction"));
});
