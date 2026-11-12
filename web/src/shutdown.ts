type ShutdownHandler = () => Promise<void> | void;

const handlers: ShutdownHandler[] = [];
let shutdownTask: Promise<void> | undefined;

/** Registers cleanup that must finish before the process exits. */
export function registerShutdownHandler(handler: ShutdownHandler): void {
  handlers.push(handler);
}

export function isShuttingDown(): boolean {
  return shutdownTask !== undefined;
}

/** Runs every registered handler once; concurrent and repeated callers share the same task. */
export function runShutdown(): Promise<void> {
  shutdownTask ??= drainHandlers();
  return shutdownTask;
}

/** Starts a graceful shutdown and returns immediately; repeated calls are ignored (signal handlers and /stop). */
export function shutdown(reason: string): void {
  if (isShuttingDown()) return;
  console.log(`Received ${reason}; shutting down...`);
  void runShutdown().catch((error: unknown) => {
    console.error("Shutdown failed", error);
    process.exitCode = 1;
  });
}

async function drainHandlers(): Promise<void> {
  const failures: unknown[] = [];
  for (const handler of handlers.splice(0)) {
    try {
      await handler();
    } catch (error) {
      failures.push(error);
    }
  }
  if (failures.length > 0) throw new AggregateError(failures, "Shutdown failed");
}
