import { mkdir } from "node:fs/promises";
import path from "node:path";
import type { Page, PageScreenshotOptions } from "playwright-core";
import { HttpError, HttpStatus } from "../http";

const ALLOWED_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp"]);

export interface ScreenshotResult {
  screenshotPath: string;
  screenshotError: string;
}

/** Captures the visible page when a non-blank absolute output path was requested. */
export async function captureScreenshot(page: Page, requestedPath?: string): Promise<ScreenshotResult> {
  const screenshotPath = requestedPath?.trim() ?? "";
  if (screenshotPath === "") return { screenshotPath: "", screenshotError: "" };
  if (!path.isAbsolute(screenshotPath)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_SCREENSHOT_PATH", "screenshotPath must be absolute");
  }

  const extension = path.extname(screenshotPath).toLowerCase();
  if (!ALLOWED_EXTENSIONS.has(extension)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_SCREENSHOT_TYPE", "screenshotPath must end with png, jpg, jpeg, or webp");
  }

  const type: PageScreenshotOptions["type"] = extension === ".png" ? "png" : extension === ".webp" ? "webp" : "jpeg";
  try {
    await mkdir(path.dirname(screenshotPath), { recursive: true });
    await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
    await page.screenshot({
      path: screenshotPath,
      type,
      quality: type === "png" ? undefined : 90,
      fullPage: false,
      animations: "allow",
      caret: "hide",
      scale: "device",
      timeout: 10_000,
    });
    return { screenshotPath, screenshotError: "" };
  } catch (error) {
    const screenshotError = error instanceof Error ? error.message : String(error);
    console.error("Screenshot failed", { screenshotPath, error: screenshotError });
    return { screenshotPath: "", screenshotError };
  }
}
