/** Shared async helpers: only promises and timers live here, domain logic stays with its service. */

/**
 * Waits for `task`, but never longer than `timeoutMs`; a task that loses the race is left to finish
 * on its own. Shared so the timer plumbing (and its `clearTimeout`) lives in one place.
 */
export async function raceTimeout(task: Promise<unknown>, timeoutMs: number): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    await Promise.race([task, new Promise<void>((resolve) => { timer = setTimeout(resolve, timeoutMs); })]);
  } finally {
    clearTimeout(timer);
  }
}
