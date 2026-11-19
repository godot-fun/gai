import { execFile } from "node:child_process";
import { once } from "node:events";
import { access, mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import path from "node:path";
import { promisify } from "node:util";
import { Camoufox } from "camoufox";
import type { BrowserContext, Page } from "playwright-core";
import { HttpError, HttpStatus } from "../http";

const execFileAsync = promisify(execFile);
const FRAMES_PER_SECOND = 60;
const READY_TIMEOUT_MS = 30_000;
const FRAME_NAME_DIGITS = 6;

interface DisplaySize {
  width: number;
  height: number;
}

interface AnimationMetadata {
  durationMs: number;
}

interface AnimationManifest {
  status: "rendering" | "completed" | "failed";
  animation: string;
  width: number;
  height: number;
  fps: number;
  durationMs: number;
  totalFrames: number;
  renderedFrames: number;
  filePattern: string;
  error: string;
}

export interface CreateAnimationRequest {
  htmlPath: string;
  outputDirectory: string;
}

/** Renders a self-contained animation HTML into a package of deterministic PNG frames. */
export class AnimationService {
  private readonly tasks = new Map<string, Promise<void>>();

  async create(request: CreateAnimationRequest): Promise<string> {
    const htmlPath = path.resolve(request.htmlPath);
    const outputDirectory = path.resolve(request.outputDirectory);
    const extension = path.extname(htmlPath).toLowerCase();
    if (extension !== ".html" && extension !== ".htm") {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_HTML_PATH", "htmlPath must end with .html or .htm");
    }
    await access(htmlPath).catch(() => {
      throw new HttpError(HttpStatus.BAD_REQUEST, "HTML_NOT_FOUND", "htmlPath does not exist or is not readable");
    });

    const animation = animationForHtml(htmlPath);
    const animationDirectory = path.join(outputDirectory, animation);
    await mkdir(outputDirectory, { recursive: true });
    try {
      await mkdir(animationDirectory);
    } catch (error) {
      if (isNodeError(error, "EEXIST")) {
        throw new HttpError(HttpStatus.CONFLICT, "ANIMATION_ALREADY_EXISTS", `Animation already exists: ${animation}`);
      }
      throw error;
    }

    const taskKey = path.normalize(animationDirectory).toLowerCase();
    const task = this.render(htmlPath, animationDirectory, animation)
      .catch((error: unknown) => console.error("Animation render failed", { animation, error }))
      .finally(() => this.tasks.delete(taskKey));
    this.tasks.set(taskKey, task);
    return animation;
  }

  async close(): Promise<void> {
    await Promise.allSettled(this.tasks.values());
  }

  private async render(htmlPath: string, animationDirectory: string, animation: string): Promise<void> {
    let context: BrowserContext | null = null;
    let manifest: AnimationManifest | null = null;
    try {
      const display = await detectLargestPhysicalDisplay();
      context = await Camoufox({
        persistent_context: true,
        user_data_dir: path.join(animationDirectory, ".browser-profile"),
        headless: true,
        viewport: display,
        screen: display,
        geoip: false,
        i_know_what_im_doing: true,
      });
      const page = await context.newPage();
      await preparePage(page, htmlPath);
      const metadata = await readAnimationMetadata(page);
      const totalFrames = Math.ceil(metadata.durationMs * FRAMES_PER_SECOND / 1_000);
      manifest = {
        status: "rendering",
        animation,
        ...display,
        fps: FRAMES_PER_SECOND,
        durationMs: metadata.durationMs,
        totalFrames,
        renderedFrames: 0,
        filePattern: `%0${FRAME_NAME_DIGITS}d.png`,
        error: "",
      };
      await writeManifest(animationDirectory, manifest);

      for (let frame = 0; frame < totalFrames; frame += 1) {
        const timeMs = frame * 1_000 / FRAMES_PER_SECOND;
        await seekAnimation(page, timeMs);
        const fileName = `${String(frame).padStart(FRAME_NAME_DIGITS, "0")}.png`;
        await page.screenshot({ path: path.join(animationDirectory, fileName), type: "png" });
        manifest.renderedFrames = frame + 1;
        if (manifest.renderedFrames % FRAMES_PER_SECOND === 0) await writeManifest(animationDirectory, manifest);
      }
      manifest.status = "completed";
      await writeManifest(animationDirectory, manifest);
    } catch (error) {
      const failed = manifest ?? {
        status: "failed" as const,
        animation,
        width: 0,
        height: 0,
        fps: FRAMES_PER_SECOND,
        durationMs: 0,
        totalFrames: 0,
        renderedFrames: 0,
        filePattern: `%0${FRAME_NAME_DIGITS}d.png`,
        error: "",
      };
      failed.status = "failed";
      failed.error = error instanceof Error ? error.message : String(error);
      await writeManifest(animationDirectory, failed).catch(() => undefined);
      throw error;
    } finally {
      await context?.close().catch(() => undefined);
      await rm(path.join(animationDirectory, ".browser-profile"), { recursive: true, force: true }).catch(() => undefined);
    }
  }
}

export function animationForHtml(htmlPath: string): string {
  const raw = path.basename(htmlPath, path.extname(htmlPath)).trim();
  const normalized = raw.replace(/[<>:"/\\|?*\u0000-\u001F]/g, "_").replace(/[. ]+$/g, "");
  if (normalized === "") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_ANIMATION", "HTML filename cannot form an animation name");
  return normalized;
}

async function preparePage(page: Page, htmlPath: string): Promise<void> {
  page.setDefaultTimeout(READY_TIMEOUT_MS);
  const html = await readFile(htmlPath, "utf8");
  if (html.trim() === "") throw new Error("Animation HTML is empty");
  // esbuild's keepNames transform references this helper inside callbacks serialized into the page.
  await page.addInitScript("globalThis.__name = globalThis.__name || ((target) => target)");
  const bridgedHtml = installAnimationBridge(html);
  const server = createServer((_request, response) => {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8", "content-length": Buffer.byteLength(bridgedHtml) });
    response.end(bridgedHtml);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("Temporary animation server did not expose a TCP port");
  try {
    await page.goto(`http://127.0.0.1:${address.port}/`, { waitUntil: "load" });
  } finally {
    server.close();
    await once(server, "close");
  }
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction("document.documentElement.dataset.animationRenderReady === 'true'");
}

async function readAnimationMetadata(page: Page): Promise<AnimationMetadata> {
  const metadata = await page.evaluate(() => ({ durationMs: Number(document.documentElement.dataset.animationRenderDuration) }));
  if (!Number.isFinite(metadata.durationMs) || metadata.durationMs <= 0) {
    throw new Error("window.__ANIMATION__.durationMs must be a positive finite number");
  }
  const canSeek = await page.evaluate(() => document.documentElement.dataset.animationRenderCanSeek === "true");
  if (!canSeek) throw new Error("window.__ANIMATION__.seek(timeMs) is required");
  return { durationMs: metadata.durationMs };
}

async function seekAnimation(page: Page, timeMs: number): Promise<void> {
  const token = `${timeMs}`;
  await page.evaluate(({ time, requestToken }) => {
    document.documentElement.dataset.animationRenderSeekTime = String(time);
    document.documentElement.dataset.animationRenderSeekToken = requestToken;
    document.dispatchEvent(new Event("animation-render-seek"));
  }, { time: timeMs, requestToken: token });
  await page.waitForFunction(`document.documentElement.dataset.animationRenderSeekDone === ${JSON.stringify(token)}`);
}

function installAnimationBridge(html: string): string {
  const bridge = `<script>
    (() => {
      const root = document.documentElement;
      const publish = () => {
        const animation = globalThis.__ANIMATION__;
        if (globalThis.__ANIMATION_READY__ !== true || !animation) return false;
        root.dataset.animationRenderReady = "true";
        root.dataset.animationRenderDuration = String(animation.durationMs);
        root.dataset.animationRenderCanSeek = String(typeof animation.seek === "function");
        return true;
      };
      if (!publish()) {
        const timer = setInterval(() => { if (publish()) clearInterval(timer); }, 10);
      }
      document.addEventListener("animation-render-seek", async () => {
        const token = root.dataset.animationRenderSeekToken || "";
        const time = Number(root.dataset.animationRenderSeekTime);
        await globalThis.__ANIMATION__.seek(time);
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        root.dataset.animationRenderSeekDone = token;
      });
    })();
  </script>`;
  const bodyEnd = html.toLowerCase().lastIndexOf("</body>");
  return bodyEnd < 0 ? `${html}${bridge}` : `${html.slice(0, bodyEnd)}${bridge}${html.slice(bodyEnd)}`;
}

async function writeManifest(animationDirectory: string, manifest: AnimationManifest): Promise<void> {
  const temporary = path.join(animationDirectory, "manifest.json.tmp");
  const target = path.join(animationDirectory, "manifest.json");
  await writeFile(temporary, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  await rm(target, { force: true });
  await rename(temporary, target);
}

/** Windows reports physical pixels after making this helper process DPI-aware. */
async function detectLargestPhysicalDisplay(): Promise<DisplaySize> {
  if (process.platform !== "win32") throw new Error("Physical display detection is currently supported only on Windows");
  const script = [
    "Add-Type -MemberDefinition '[System.Runtime.InteropServices.DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware();' -Name Dpi -Namespace Native",
    "[Native.Dpi]::SetProcessDPIAware() | Out-Null",
    "Add-Type -AssemblyName System.Windows.Forms",
    "$screens = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { @{ width = $_.Bounds.Width; height = $_.Bounds.Height } }",
    "$screens | ConvertTo-Json -Compress",
  ].join("; ");
  const { stdout } = await execFileAsync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { windowsHide: true });
  const parsed: unknown = JSON.parse(stdout.trim());
  const displays = (Array.isArray(parsed) ? parsed : [parsed]).filter(isDisplaySize);
  if (displays.length === 0) throw new Error("No physical display resolution is available");
  return displays.reduce((largest, display) => display.width * display.height > largest.width * largest.height ? display : largest);
}

function isDisplaySize(value: unknown): value is DisplaySize {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return Number.isSafeInteger(candidate.width) && Number(candidate.width) > 0 && Number.isSafeInteger(candidate.height) && Number(candidate.height) > 0;
}

function isNodeError(error: unknown, code: string): boolean {
  return error instanceof Error && "code" in error && error.code === code;
}

export const animationService = new AnimationService();
