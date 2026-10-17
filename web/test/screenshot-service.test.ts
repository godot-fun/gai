import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import type { Page } from "playwright-core";
import { HttpError } from "../src/http";
import { captureScreenshot } from "../src/services/screenshot-service";

test("captureScreenshot skips blank paths", async () => {
  let called = false;
  const page = { screenshot: async () => { called = true; } } as unknown as Page;
  assert.deepEqual(await captureScreenshot(page, "  "), { screenshotPath: "", screenshotError: "" });
  assert.equal(called, false);
});

test("captureScreenshot saves to the requested absolute path", async () => {
  const temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), "gai-screenshot-"));
  const screenshotPath = path.join(temporaryDirectory, "nested", "page.webp");
  const page = {
    evaluate: async () => undefined,
    screenshot: async (options: { path?: string }) => {
      const { writeFile } = await import("node:fs/promises");
      await writeFile(options.path!, "image");
    },
  } as unknown as Page;

  try {
    assert.deepEqual(await captureScreenshot(page, screenshotPath), { screenshotPath, screenshotError: "" });
    assert.equal((await readFile(screenshotPath)).toString(), "image");
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test("captureScreenshot rejects relative paths", async () => {
  const page = {} as Page;
  await assert.rejects(() => captureScreenshot(page, "page.webp"), HttpError);
});
