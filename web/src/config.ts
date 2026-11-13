import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ProxyAgent, setGlobalDispatcher } from "undici";

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// ---------------------------------------------------------------------------------------------------------------------
export interface ServerConfig {
  host: string;
  port: number;
  headless: boolean;
  userDataDir: string;
  /** Playwright browsers dir; `0` means node_modules/playwright-core/.local-browsers. */
  playwrightBrowsersPath: string;
  proxy: string;
  browserMaxConcurrency: number;
  navigationTimeoutMs: number;
  requestTimeoutMs: number;
  mcpConfigPath: string;
}

function resolvePlaywrightBrowsersPath(raw: string): string {
  const value = raw.trim() || "0";
  if (value === "0" || path.isAbsolute(value)) return value;
  return path.resolve(packageRoot, value);
}

function readPositiveInteger(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error(`${name} must be a positive integer`);
  return value;
}

function readBoolean(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  if (raw === "true") return true;
  if (raw === "false") return false;
  throw new Error(`${name} must be true or false`);
}

function readArgument(name: string): string {
  const prefix = `--${name}=`;
  return process.argv.find((argument) => argument.startsWith(prefix))?.slice(prefix.length).trim() || "";
}

function readBooleanArgument(name: string): boolean | undefined {
  const raw = readArgument(name);
  if (raw === "") return undefined;
  if (raw === "true") return true;
  if (raw === "false") return false;
  throw new Error(`--${name} must be true or false`);
}

export function loadConfig(): ServerConfig {
  return {
    host: process.env.HOST?.trim() || "127.0.0.1",
    port: readPositiveInteger("PORT", 3000),
    headless: readBooleanArgument("browser-headless") ?? readBoolean("BROWSER_HEADLESS", true),
    userDataDir: process.env.BROWSER_USER_DATA_DIR?.trim() || "./.user_data",
    playwrightBrowsersPath: resolvePlaywrightBrowsersPath(process.env.PLAYWRIGHT_BROWSERS_PATH ?? "0"),
    proxy: readArgument("proxy-address") || process.env.BROWSER_PROXY?.trim() || "",
    browserMaxConcurrency: readPositiveInteger("BROWSER_MAX_CONCURRENCY", 4),
    navigationTimeoutMs: readPositiveInteger("NAVIGATION_TIMEOUT_MS", 30_000),
    requestTimeoutMs: readPositiveInteger("REQUEST_TIMEOUT_MS", 45_000),
    mcpConfigPath: process.env.MCP_CONFIG_PATH?.trim() || "mcp.json",
  };
}

export const config = loadConfig();
process.env.PLAYWRIGHT_BROWSERS_PATH = config.playwrightBrowsersPath;

export function isProxyEnabled(): boolean {
  return config.proxy !== "";
}

if (isProxyEnabled()) {
  setGlobalDispatcher(new ProxyAgent(config.proxy));
  console.log(`Proxy enabled address:[${config.proxy}]`);
  console.log(`Working path:[${process.cwd()}]`);
}
