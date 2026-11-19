import { execFile } from "node:child_process";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import type { Page } from "playwright-core";
import { HttpError, HttpStatus } from "../http";
import { browserService } from "./browser-service";

const FRAMES_PER_SECOND = 60;

interface DisplaySize {
  width: number;
  height: number;
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

export interface AnimationStatus {
  status: AnimationManifest["status"];
  error: string;
}

/** Renders a self-contained HTML animation into deterministic PNG frames. */
export class AnimationService {
  private readonly tasks = new Map<string, Promise<void>>();

  async create(request: CreateAnimationRequest): Promise<string> {
    const { htmlPath, outputDirectory } = request;
    const animation = path.parse(htmlPath).name;
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

  async query(animation: string, outputDirectory: string): Promise<AnimationStatus> {
    const animationDirectory = path.join(outputDirectory, animation);
    const taskKey = path.normalize(animationDirectory).toLowerCase();
    if (this.tasks.has(taskKey)) return { status: "rendering", error: "" };
    try {
      const manifest = JSON.parse(await readFile(path.join(animationDirectory, "manifest.json"), "utf8")) as AnimationManifest;
      return { status: manifest.status, error: manifest.error };
    } catch (error) {
      if (isNodeError(error, "ENOENT")) throw new HttpError(HttpStatus.NOT_FOUND, "ANIMATION_NOT_FOUND", `Animation not found: ${animation}`);
      throw error;
    }
  }

  async close(): Promise<void> {
    await Promise.allSettled(this.tasks.values());
  }

  private async render(htmlPath: string, animationDirectory: string, animation: string): Promise<void> {
    let page: Page | null = null;
    let manifest: AnimationManifest | null = null;
    try {
      const display = await detectLargestPhysicalDisplay();
      page = await browserService.openPage();
      await page.setViewportSize(display);
      await preparePage(page, htmlPath);
      const durationMs = await readAnimationDuration(page);
      const totalFrames = Math.ceil(durationMs * FRAMES_PER_SECOND / 1_000);
      manifest = {
        status: "rendering",
        animation,
        ...display,
        fps: FRAMES_PER_SECOND,
        durationMs,
        totalFrames,
        renderedFrames: 0,
        filePattern: "%06d.png",
        error: "",
      };
      await writeManifest(animationDirectory, manifest);

      for (let frame = 0; frame < totalFrames; frame += 1) {
        const timeMs = frame * 1_000 / FRAMES_PER_SECOND;
        await seekAnimation(page, timeMs);
        const fileName = `${String(frame).padStart(6, "0")}.png`;
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
        filePattern: "%06d.png",
        error: "",
      };
      failed.status = "failed";
      failed.error = error instanceof Error ? error.message : String(error);
      await writeManifest(animationDirectory, failed).catch(() => undefined);
      throw error;
    } finally {
      await page?.close().catch(() => undefined);
    }
  }
}

async function preparePage(page: Page, htmlPath: string): Promise<void> {
  // esbuild's keepNames transform references this helper inside callbacks serialized into the page.
  await page.addInitScript("globalThis.__name = globalThis.__name || ((target) => target)");
  await page.goto(pathToFileURL(htmlPath).href, { waitUntil: "load" });
  await page.addScriptTag({ content: ANIMATION_BRIDGE });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction("document.documentElement.dataset.animationRenderReady === 'true'");
}

async function readAnimationDuration(page: Page): Promise<number> {
  const durationMs = await page.evaluate(() => Number(document.documentElement.dataset.animationRenderDuration));
  if (!Number.isFinite(durationMs) || durationMs <= 0) {
    throw new Error("window.__ANIMATION__.durationMs must be a positive finite number");
  }
  const canSeek = await page.evaluate(() => document.documentElement.dataset.animationRenderCanSeek === "true");
  if (!canSeek) throw new Error("window.__ANIMATION__.seek(timeMs) is required");
  return durationMs;
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

const ANIMATION_BRIDGE = `
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
`;

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
  const stdout = await new Promise<string>((resolve, reject) => {
    execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { windowsHide: true }, (error, output) => {
      if (error) reject(error);
      else resolve(output);
    });
  });
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
