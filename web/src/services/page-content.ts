import type { Page } from "playwright-core";
import { Defuddle, type DefuddleResponse } from "defuddle/node";

/**
 * Readable Markdown extraction shared by `/fetch` and the `markdown` browser step.
 *
 * The browser step reads the page *as it is right now*, so the result reflects login state,
 * SPA navigation, and whatever a click just changed — which a fresh fetch of the same URL does not.
 */

export async function extractPageContent(page: Page): Promise<DefuddleResponse> {
  return Defuddle(await page.content(), page.url(), { markdown: true, useAsync: false });
}
