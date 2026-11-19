// ---------------------------------------------------------------------------------------------------------------------
// Async

/** Waits for `task` until `timeoutMs`; a task that loses the race is left to finish on its own. */
export async function raceTimeout(task: Promise<unknown>, timeoutMs: number): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    await Promise.race([task, new Promise<void>((resolve) => { timer = setTimeout(resolve, timeoutMs); })]);
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Strings

/** Replaces characters outside `[A-Za-z0-9_-]` so a name is safe for tool registries. */
export function sanitizeName(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_");
}

/** A value is blank when it is absent or contains only whitespace. */
export function isBlank(value: string | undefined): boolean {
  return (value ?? "").trim() === "";
}

// ---------------------------------------------------------------------------------------------------------------------
// Errors

/** Returns the useful message of an Error and a safe string for any other thrown value. */
export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Checks an Error name without assuming the caught value is an Error. */
export function isErrorNamed(error: unknown, name: string): boolean {
  return error instanceof Error && error.name === name;
}

// ---------------------------------------------------------------------------------------------------------------------
// URLs

/** Parses an absolute HTTP(S) URL, returning null for malformed or unsupported URLs. */
export function parseHttpUrl(raw: string): URL | null {
  try {
    const url = new URL(raw.trim());
    return url.protocol === "http:" || url.protocol === "https:" ? url : null;
  } catch {
    return null;
  }
}
