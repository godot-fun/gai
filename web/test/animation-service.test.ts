import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { AnimationService, animationForHtml } from "../src/services/animation-service";

test("animation defaults to the HTML filename", () => {
  assert.equal(animationForHtml("C:/animations/product-intro.html"), "product-intro");
  assert.equal(animationForHtml("C:/animations/产品介绍.htm"), "产品介绍");
});

test("animation replaces filename characters Windows cannot store", () => {
  assert.equal(animationForHtml("C:/animations/product%3Aintro.html"), "product%3Aintro");
  assert.equal(animationForHtml("C:/animations/product|intro.html"), "product_intro");
});

test("animation renders a real HTML frame in headless mode", async () => {
  const temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), "gai-animation-package-"));
  const htmlPath = path.join(temporaryDirectory, "one-frame.html");
  const outputDirectory = path.join(temporaryDirectory, "output");
  const service = new AnimationService();
  await writeFile(htmlPath, `<!doctype html><html><body><script>
    globalThis.__ANIMATION__ = {
      durationMs: 1,
      seek(timeMs) { document.body.style.background = timeMs === 0 ? "rgb(1, 2, 3)" : "black"; }
    };
    globalThis.__ANIMATION_READY__ = true;
  </script></body></html>`, "utf8");
  try {
    assert.equal(await service.create({ htmlPath, outputDirectory }), "one-frame");
    await service.close();
    const animationDirectory = path.join(outputDirectory, "one-frame");
    assert.ok((await stat(path.join(animationDirectory, "000000.png"))).size > 0);
    const manifest = JSON.parse(await readFile(path.join(animationDirectory, "manifest.json"), "utf8")) as { status: string; totalFrames: number };
    assert.deepEqual(manifest, { ...manifest, status: "completed", totalFrames: 1 });
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});
