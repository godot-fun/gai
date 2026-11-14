import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, HttpStatus, optionalString, readJsonBody, requireObject, sendOk } from "../http";
import { BROWSER_STEP_ACTIONS, browserSession, type BrowserStep, type BrowserStepAction } from "../services/browser-session";
import { validateScreenshotPath } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

/** One request may chain a few steps, but the HTTP timeout bounds how many can finish. */
const MAX_STEPS = 12;

/** String fields an action cannot run without; a targeted action additionally needs `ref` or `selector`. */
const FIELDS: Readonly<Record<BrowserStepAction, readonly string[]>> = {
  goto: ["url"],
  snapshot: [],
  markdown: [],
  click: [],
  type: ["text"],
  press: ["key"],
  hover: [],
  select: ["value"],
  scroll: [],
  back: [],
  forward: [],
  reload: [],
};

/** Actions that only need a target plus something to do with it. */
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
  for (const field of ["url", "ref", "selector", "text", "key", "value"] as const) {
    const raw = optionalString(step[field], `steps[${index}].${field}`);
    if (raw !== undefined) parsed[field] = raw;
  }
  const direction = step.direction;
  if (direction !== undefined) {
    if (direction !== "up" && direction !== "down") throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}].direction must be up or down`);
    parsed.direction = direction;
  }
  validateFields(parsed, index);
  return parsed;
}

/** Fails the whole request when a step cannot possibly run; the message names the action and field. */
function validateFields(step: BrowserStep, index: number): void {
  for (const field of FIELDS[step.action]) {
    const value = step[field as keyof BrowserStep];
    if (typeof value !== "string" || value.trim() === "") {
      throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${step.action} needs a non-empty ${field}`);
    }
  }
  if (!TARGETED.includes(step.action)) return;
  const hasRef = (step.ref ?? "").trim() !== "";
  const hasSelector = (step.selector ?? "").trim() !== "";
  if (!hasRef && !hasSelector) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${step.action} needs a ref from the last snapshot, or a selector`);
  }
}

function isStepAction(value: string): value is BrowserStepAction {
  return (BROWSER_STEP_ACTIONS as readonly string[]).includes(value);
}

registerApi(new BrowserActionApi());
