import path from "node:path";
import { pathToFileURL } from "node:url";
import type { Page } from "playwright-core";
import { HttpError, HttpStatus } from "../http";
import { browserService } from "./browser-service";

/** The key that starts an animation page; every generated page stays paused until it arrives. */
const START_KEY = "Space";
/** Two frames after the open prove the page has painted the frame the start key will move. */
const FRAME_TIMEOUT_MS = 10_000;

export interface AnimationInfo {
  animation: string;
  /** System wall clock (epoch ms) of the operation, for correlating recorder logs. */
  requestedWallClockMs: number;
}

export interface OpenResult extends AnimationInfo {
  /** `document.title` of the loaded page, used to find its window on screen. */
  title: string;
  /** Declared animation duration, so callers never parse the HTML themselves. */
  durationMs: number;
  /** Wall clock of the moment the paused first frame was on screen and ready for the start key. */
  openedWallClockMs: number;
}

export interface PlayResult extends AnimationInfo {
  /** Wall clock of the key press that started the timeline — where a recorder cuts its video. */
  playedWallClockMs: number;
}

/**
 * Drives one self-contained HTML animation in the shared browser tab.
 *
 * The animation is opened first and stays paused on its first frame, so a recorder can maximize the
 * window and start capturing before anything moves. `play` then presses Space and answers at once:
 * browser startup, page load and window placement no longer have to fit inside the recording.
 * The tab is reused, so a second `open` navigates away from the previous animation: record one
 * animation at a time.
 */
export class AnimationService {
  private page: Page | null = null;

  /** Loads the page and returns once its paused first frame is on screen. */
  async open(htmlPath: string, durationSeconds?: number): Promise<OpenResult> {
    const requestedWallClockMs = Date.now();
    const page = await this.browserPage();
    await page.bringToFront();
    // The query marker makes every navigation a fresh URL, so the wait below never matches the
    // lifecycle of the document the tab served before.
    await page.goto(`${pathToFileURL(htmlPath).href}?gai=${requestedWallClockMs}`, { waitUntil: "load" });
    await waitForFirstFrame(page);
    return {
      animation: path.parse(htmlPath).name,
      requestedWallClockMs,
      title: await readTitle(page),
      durationMs: await readDurationMs(page, durationSeconds),
      openedWallClockMs: Date.now(),
    };
  }

  /** Presses Space in the loaded page: the timeline starts on that key and never before it. */
  async play(): Promise<PlayResult> {
    const page = this.page;
    if (page === null || page.isClosed()) {
      throw new HttpError(
        HttpStatus.CONFLICT,
        "ANIMATION_NOT_OPEN",
        "No animation is open: call /animation/open before /animation/play",
      );
    }
    const requestedWallClockMs = Date.now();
    await page.keyboard.press(START_KEY);
    return {
      animation: path.parse(new URL(page.url()).pathname).name,
      requestedWallClockMs,
      playedWallClockMs: Date.now(),
    };
  }

  /** Closes the playback tab; the next `open` starts from a new page. */
  async close(): Promise<void> {
    const page = this.page;
    this.page = null;
    await page?.close().catch(() => undefined);
  }

  /** One reused page keeps the animation in a single tab instead of a new tab per animation. */
  private async browserPage(): Promise<Page> {
    const existing = this.page;
    if (existing !== null && !existing.isClosed()) return existing;
    this.page = await browserService.openPage();
    return this.page;
  }
}

async function readTitle(page: Page): Promise<string> {
  return await page.evaluate(() => document.title);
}

/** Reads the declaration from the loaded page, so callers do not have to parse the HTML themselves. */
async function readDurationMs(page: Page, durationSeconds?: number): Promise<number> {
  const declared = durationSeconds ?? await page.evaluate(() => {
    const content = document.querySelector<HTMLMetaElement>('meta[name="animation-duration"]')?.content;
    return Number(content);
  });
  const durationMs = declared * 1_000;
  if (!Number.isFinite(durationMs) || durationMs <= 0) {
    throw new HttpError(
      HttpStatus.BAD_REQUEST,
      "INVALID_ANIMATION_DURATION",
      'The page must declare <meta name="animation-duration" content="15"> or the request must send duration in seconds',
    );
  }
  return durationMs;
}

/** Waits until the page has drawn its paused first frame, so the recording starts on real content. */
async function waitForFirstFrame(page: Page): Promise<void> {
  await page.evaluate(
    (timeoutMs) =>
      new Promise<void>((resolve) => {
        const timer = setTimeout(resolve, timeoutMs);
        requestAnimationFrame(() =>
          requestAnimationFrame(() => {
            clearTimeout(timer);
            resolve();
          }),
        );
      }),
    FRAME_TIMEOUT_MS,
  );
}

export const animationService = new AnimationService();
