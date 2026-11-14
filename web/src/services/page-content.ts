import type { Page } from "playwright-core";
import { Defuddle } from "defuddle/node";

/**
 * Readable Markdown extraction shared by `/fetch` and the `markdown` browser step.
 *
 * The browser step reads the page *as it is right now*, so the result reflects login state,
 * SPA navigation, and whatever a click just changed — which a fresh fetch of the same URL does not.
 */

export type PageContent = Awaited<ReturnType<typeof Defuddle>>;

export async function extractPageContent(page: Page): Promise<PageContent> {
  const html = await page.content();
  return Defuddle(html, page.url(), { markdown: true, useAsync: false });
}
