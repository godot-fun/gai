import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, HttpStatus, optionalString, readJsonBody, requireObject, requireString, sendOk } from "../http";
import { BROWSER_OBSERVE_MODES, BROWSER_STEP_ACTIONS, browserSession, type BrowserObserveMode, type BrowserStep, type BrowserStepAction } from "../services/browser-session";
import { validateScreenshotPath } from "../services/screenshot-service";
import { registerApi, type ApiRoute } from "./route";

/** One request may chain a few steps, but the HTTP timeout bounds how many can finish. */
const MAX_STEPS = 12;

/** The action list as a lookup table, so validating a step does not scan the array. */
const STEP_ACTIONS = new Set<string>(BROWSER_STEP_ACTIONS);
const OBSERVE_MODES = new Set<string>(BROWSER_OBSERVE_MODES);

/** The plain text fields a step can carry; `action` and `direction` are handled on their own. */
type StepField = "ref" | "selector" | "text" | "key" | "value";

/**
 * Fields each action reads. A step is parsed from its action, so a field that does not belong to it
 * is dropped instead of forwarded — the same rule the tool layer applies before sending.
 */
const FIELDS: Readonly<Record<BrowserStepAction, readonly StepField[]>> = {
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
  type: "text",
  press: "key",
  select: "value",
};

/** Actions that cannot run without an element: a ref from the last snapshot, or a selector once it is stale. */
const NEEDS_TARGET: readonly BrowserStepAction[] = ["click", "type", "hover", "select"];

/**
 * Runs browser steps against the shared page and captures their final visual state.
 *
 * A failing step is reported with `200` and `ok: false` so the model sees the reason and the state
 * it failed in; only a malformed request (unknown action, missing field, bad screenshot path) is a 4xx.
 */
export class BrowserActionApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/browser/action";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const screenshotPath = requireString(body.screenshotPath, "screenshotPath");
    validateScreenshotPath(screenshotPath);
    const steps = readSteps(body.steps);
    sendOk(response, await browserSession.act(steps, screenshotPath));
  }
}

export class BrowserOpenApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/browser/open";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    sendOk(response, await browserSession.open(requireString(body.url, "url")));
  }
}

export class BrowserObserveApi implements ApiRoute {
  readonly method = "POST";
  readonly path = "/browser/observe";

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body = requireObject(await readJsonBody(request));
    const mode = readObserveMode(body.mode);
    const screenshotPath = mode === "screenshot" ? requireString(body.screenshotPath, "screenshotPath") : undefined;
    validateScreenshotPath(screenshotPath);
    sendOk(response, await browserSession.observe(mode, screenshotPath));
  }
}

function readObserveMode(value: unknown): BrowserObserveMode {
  if (typeof value !== "string" || !OBSERVE_MODES.has(value)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `mode must be one of: ${BROWSER_OBSERVE_MODES.join(", ")}`);
  }
  return value as BrowserObserveMode;
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
    if (direction === "up" || direction === "down") parsed.direction = direction;
    else if (direction !== undefined) throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}].direction must be up or down`);
  }

  const required = REQUIRED[action];
  if (required !== undefined && isBlank(parsed[required])) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${action} needs a non-empty ${required}`);
  }
  if (NEEDS_TARGET.includes(action) && isBlank(parsed.ref) && isBlank(parsed.selector)) {
    throw new HttpError(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", `steps[${index}] ${action} needs a ref from the last snapshot, or a selector`);
  }
  return parsed;
}

/** A field counts as given only when something survives trimming. */
function isBlank(value: string | undefined): boolean {
  return (value ?? "").trim() === "";
}

function isStepAction(value: string): value is BrowserStepAction {
  return STEP_ACTIONS.has(value);
}

registerApi(new BrowserActionApi());
registerApi(new BrowserOpenApi());
registerApi(new BrowserObserveApi());
