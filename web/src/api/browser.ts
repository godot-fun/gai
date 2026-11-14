import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, HttpStatus, optionalString, readJsonBody, requireObject, sendOk } from "../http";
import { BROWSER_STEP_ACTIONS, browserSession, type BrowserStep, type BrowserStepAction } from "../services/browser-session";
import { validateScreenshotPath } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

/** One request may chain a few steps, but the HTTP timeout bounds how many can finish. */
const MAX_STEPS = 12;

/** The plain text fields a step can carry; `action` and `direction` are handled on their own. */
type StepField = "url" | "ref" | "selector" | "text" | "key" | "value";

/**
 * Fields each action reads. A step is parsed from its action, so a field that does not belong to it
 * is dropped instead of forwarded — the same rule the tool layer applies before sending.
 */
const FIELDS: Readonly<Record<BrowserStepAction, readonly StepField[]>> = {
  goto: ["url"],
  snapshot: [],
  markdown: [],
  click: ["ref", "selector"],
  type: ["ref", "selector", "text"],
  press: ["ref", "selector", "key"],
  hover: ["ref", "selector"],
  select: ["ref", "selector", "value"],
  scroll: ["ref", "selector"],
  back: [],
  forward: [],
  reload: [],
};

/** The one field an action cannot run without. */
const REQUIRED: Readonly<Partial<Record<BrowserStepAction, StepField>>> = {
  goto: "url",
  type: "text",
  press: "key",
  select: "value",
};

/** Actions that only work on an element: a ref from the last snapshot, or a selector once it is stale. */
const TARGETED: readonly BrowserStepAction[] = ["click", "type", "hover", "select"];

/**
 * Runs browser steps against the shared page and answers with the page metadata plus a snapshot.
 *
 * A failing step is reported with `200` and `ok: false` so the model sees the reason and the state
 * it failed in; only a malformed request (unknown action, missing field, bad screenshot path) is a 4xx.
 */
export class BrowserActionApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/browser/action";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const screenshotPath = optionalString(body.screenshotPath, "screenshotPath");
    // Reject an unusable screenshot path before spending steps on the page.
    validateScreenshotPath(screenshotPath);
    const steps = readSteps(body.steps);
    const snapshot = readSnapshotFlag(body.snapshot);
    sendOk(response, await browserSession.run({ steps, snapshot, screenshotPath }));
  }
}

function readSnapshotFlag(value: unknown): boolean {
  if (value === undefined) return true;
  if (typeof value !== "boolean") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "snapshot must be a boolean");
  return value;
}

function readSteps(value: unknown): BrowserStep[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "steps must be a non-empty array");
  }
  if (value.length > MAX_STEPS) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "TOO_MANY_STEPS", `steps must hold at most ${MAX_STEPS} entries`);
  }
  return value.map((entry, index) => readStep(entry, index));
}

function readStep(value: unknown, index: number): BrowserStep {
  const step = requireObject(value);
  const action = step.action;
  if (typeof action !== "string" || !isStepAction(action)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_ACTION", `steps[${index}].action must be one of: ${BROWSER_STEP_ACTIONS.join(", ")}`);
  }
  const parsed: BrowserStep = { action };
  for (const field of FIELDS[action]) {
    const raw = optionalString(step[field], `steps[${index}].${field}`);
    if (raw !== undefined) parsed[field] = raw;
  }
  if (action === "scroll") {
    const direction = optionalString(step.direction, `steps[${index}].direction`);
    if (direction !== undefined) {
      if (direction !== "up" && direction !== "down") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}].direction must be up or down`);
      parsed.direction = direction;
    }
  }

  const required = REQUIRED[action];
  if (required !== undefined && (parsed[required] ?? "").trim() === "") {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${action} needs a non-empty ${required}`);
  }
  if (TARGETED.includes(action) && (parsed.ref ?? "").trim() === "" && (parsed.selector ?? "").trim() === "") {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${action} needs a ref from the last snapshot, or a selector`);
  }
  return parsed;
}

function isStepAction(value: string): value is BrowserStepAction {
  return (BROWSER_STEP_ACTIONS as readonly string[]).includes(value);
}

registerApi(new BrowserActionApi());
