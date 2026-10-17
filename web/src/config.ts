import "dotenv/config";
// download cloak browser for proxy
// import {setGlobalDispatcher, ProxyAgent} from "undici"
// setGlobalDispatcher(new ProxyAgent("http://127.0.0.1:10809"))
// console.log(`cloak browser path:[${process.env.CLOAKBROWSER_CACHE_DIR}]`);
// console.log(`working path:[${process.cwd()}]`);


// ---------------------------------------------------------------------------------------------------------------------
export interface ServerConfig {
  host: string;
  port: number;
  headless: boolean;
  userDataDir: string;
  browserMaxConcurrency: number;
  browserQueueLimit: number;
  navigationTimeoutMs: number;
  requestTimeoutMs: number;
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

export function loadConfig(): ServerConfig {
  return {
    host: process.env.HOST?.trim() || "127.0.0.1",
    port: readPositiveInteger("PORT", 3000),
    headless: readBoolean("CLOAKBROWSER_HEADLESS", true),
    userDataDir: process.env.CLOAKBROWSER_USER_DATA_DIR?.trim() || "./.user_data",
    browserMaxConcurrency: readPositiveInteger("BROWSER_MAX_CONCURRENCY", 4),
    browserQueueLimit: readPositiveInteger("BROWSER_QUEUE_LIMIT", 32),
    navigationTimeoutMs: readPositiveInteger("NAVIGATION_TIMEOUT_MS", 30_000),
    requestTimeoutMs: readPositiveInteger("REQUEST_TIMEOUT_MS", 45_000),
  };
}
