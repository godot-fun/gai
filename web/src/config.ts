import path from "node:path";
import dotenv from "dotenv";
import { ProxyAgent, setGlobalDispatcher } from "undici";

// Windows already sets LOCALAPPDATA; override so .env can replace it before camoufox loads.
dotenv.config({ override: true });

const localAppData = (process.env.LOCALAPPDATA ?? "").trim();
if (localAppData !== "") {
  const absolute = path.resolve(localAppData);
  process.env.LOCALAPPDATA = absolute;
  if (process.platform !== "win32" && process.platform !== "darwin") {
    process.env.XDG_CACHE_HOME = absolute;
  }
  console.log(`Camoufox LOCALAPPDATA:[${absolute}]`);
}


// ---------------------------------------------------------------------------------------------------------------------
export interface ServerConfig {
  host: string;
  port: number;
  headless: boolean;
  userDataDir: string;
  proxy: string;
  navigationTimeoutMs: number;
  requestTimeoutMs: number;
  mcpConfigPath: string;
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
  return raw === undefined || raw.trim() === "" ? fallback : parseBoolean(raw, name);
}

function readArgument(name: string): string {
  const prefix = `--${name}=`;
  return process.argv.find((argument) => argument.startsWith(prefix))?.slice(prefix.length).trim() || "";
}

function readBooleanArgument(name: string): boolean | undefined {
  const raw = readArgument(name);
  return raw === "" ? undefined : parseBoolean(raw, `--${name}`);
}

/** Both the environment and the command line spell a boolean the same way: `true` or `false`. */
function parseBoolean(raw: string, name: string): boolean {
  if (raw === "true") return true;
  if (raw === "false") return false;
  throw new Error(`${name} must be true or false`);
}

export function loadConfig(): ServerConfig {
  return {
    host: process.env.HOST?.trim() || "127.0.0.1",
    port: readPositiveInteger("PORT", 3000),
    headless: readBooleanArgument("browser-headless") ?? readBoolean("BROWSER_HEADLESS", true),
    userDataDir: process.env.CAMOUFOX_USER_DATA_DIR?.trim() || "./.user_data",
    proxy: readArgument("proxy-address") || process.env.BROWSER_PROXY?.trim() || "",
    navigationTimeoutMs: readPositiveInteger("NAVIGATION_TIMEOUT_MS", 30_000),
    requestTimeoutMs: readPositiveInteger("REQUEST_TIMEOUT_MS", 45_000),
    mcpConfigPath: process.env.MCP_CONFIG_PATH?.trim() || "mcp.json",
  };
}

export const config = loadConfig();

export function isProxyEnabled(): boolean {
  return config.proxy !== "";
}

// Route downloads (the Camoufox browser binary) through the configured proxy as well.
if (isProxyEnabled()) {
  setGlobalDispatcher(new ProxyAgent(config.proxy));
  console.log(`Proxy enabled address:[${config.proxy}]`);
  console.log(`Working path:[${process.cwd()}]`);
}
