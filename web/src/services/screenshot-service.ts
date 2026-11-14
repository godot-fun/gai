import { mkdir } from "node:fs/promises";
import path from "node:path";
import type { Page, PageScreenshotOptions } from "playwright-core";
import { HttpError, HttpStatus } from "../http";
import { raceTimeout } from "../async-utils";

/** Extension -> the format Playwright writes; anything else is rejected before a page is opened. */
const SCREENSHOT_FORMATS = new Map<string, PageScreenshotOptions["type"]>([
  [".png", "png"],
  [".webp", "webp"],
  [".jpg", "jpeg"],
  [".jpeg", "jpeg"],
]);
// A hidden or script-blocked page never runs requestAnimationFrame; never wait longer than this.
const LAYOUT_SETTLE_TIMEOUT_MS = 1_000;

interface ScreenshotOptions {
  path: string;
  type: PageScreenshotOptions["type"];
  quality: number | undefined;
}

export interface ScreenshotResult {
  screenshotPath: string;
  screenshotError: string;
}

/** Throws when a requested screenshot path is unusable, so callers can fail before opening a page. */
export function validateScreenshotPath(requestedPath?: string): void {
  resolveScreenshotOptions(requestedPath);
}

/** Captures the visible page when a non-blank absolute output path was requested. */
export async function captureScreenshot(page: Page, requestedPath?: string): Promise<ScreenshotResult> {
  const options = resolveScreenshotOptions(requestedPath);
  if (options === null) return { screenshotPath: "", screenshotError: "" };

  try {
    await mkdir(path.dirname(options.path), { recursive: true });
    await waitForLayout(page);
    await page.screenshot({
      path: options.path,
      type: options.type,
      quality: options.quality,
      fullPage: false,
      animations: "allow",
      caret: "hide",
      scale: "device",
      timeout: 10_000,
    });
    return { screenshotPath: options.path, screenshotError: "" };
  } catch (error) {
    const screenshotError = error instanceof Error ? error.message : String(error);
    console.error("Screenshot failed", { screenshotPath: options.path, error: screenshotError });
    return { screenshotPath: "", screenshotError };
  }
}

function resolveScreenshotOptions(requestedPath?: string): ScreenshotOptions | null {
  const screenshotPath = requestedPath?.trim() ?? "";
  if (screenshotPath === "") return null;
  if (!path.isAbsolute(screenshotPath)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_SCREENSHOT_PATH", "screenshotPath must be absolute");
  }

  const type = SCREENSHOT_FORMATS.get(path.extname(screenshotPath).toLowerCase());
  if (type === undefined) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_SCREENSHOT_TYPE", "screenshotPath must end with png, jpg, jpeg, or webp");
  }
  return { path: screenshotPath, type, quality: type === "png" ? undefined : 100 };
}

/** Waits two animation frames so late layout work lands in the capture, bounded by a timeout. */
async function waitForLayout(page: Page): Promise<void> {
  const frames = page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  // A page that cannot evaluate scripts still gets its screenshot.
  await raceTimeout(frames, LAYOUT_SETTLE_TIMEOUT_MS).catch(() => undefined);
}
