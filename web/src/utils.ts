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

/** Trims an optional string and turns an absent value into an empty string. */
export function trimOrEmpty(value: string | undefined): string {
  return value?.trim() ?? "";
}

/** A value is blank when it is absent or contains only whitespace. */
export function isBlank(value: string | undefined): boolean {
  return trimOrEmpty(value) === "";
}

/** Narrows an unknown value to one of the strings in a readonly list. */
export function isOneOf<T extends string>(value: unknown, values: readonly T[]): value is T {
  return typeof value === "string" && values.includes(value as T);
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
