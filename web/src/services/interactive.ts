import type { SnapshotNode } from "./snapshot";

/**
 * Two-phase page observation.
 *
 * Phase one ([function collectInteractiveCandidates]) runs inside the page and collects *every*
 * element Playwright could interact with, plus the facts a filter needs (role, name, value, state,
 * region, rendered, enabled). Nothing is budgeted there, so recall does not depend on DOM order or
 * tree depth — the two ways the older tree walk used to drop whole regions.
 *
 * Phase two ([function selectCandidates]) runs here and decides what the model actually gets: keep
 * rendered, enabled, name-bearing elements, collapse duplicates, and spend a fixed budget on the most
 * useful elements rather than on the first ones in the document.
 */

/** One interactable element, collected before any budget is applied. */
export interface InteractiveCandidate {
  role: string;
  name: string;
  value: string;
  state: string;
  /** Nearest landmark role around the element (`main`, `navigation`, ...), empty when none. */
  regionRole: string;
  regionName: string;
  /** Has a box, is not `visibility: hidden`, and takes pointer events. */
  rendered: boolean;
  enabled: boolean;
  /** Model-facing handle: `e12` in the main frame, `f2e12` inside the second frame. */
  ref: string;
}

/** How much of the page one snapshot may spend. */
export interface SnapshotLimits {
  maxElements: number;
  /** Links are the noisy role on content pages, so they get their own ceiling. */
  maxLinks: number;
  /** Identical role+name pairs beyond this are navigation/footer duplicates. */
  maxPerName: number;
}

export const DEFAULT_LIMITS: SnapshotLimits = { maxElements: 300, maxLinks: 180, maxPerName: 2 };

/** Form controls are what a task needs; links are usually navigation and arrive last. */
const ROLE_PRIORITY: Readonly<Record<string, number>> = {
  textbox: 0,
  searchbox: 0,
  combobox: 0,
  checkbox: 0,
  radio: 0,
  switch: 0,
  slider: 0,
  spinbutton: 0,
  button: 1,
  summary: 1,
  tab: 1,
  menuitem: 1,
  option: 1,
  link: 2,
};

/** Roles that stay useful without an accessible name, because their value carries them. */
const NAME_OPTIONAL = new Set(["textbox", "searchbox", "combobox", "checkbox", "radio", "switch", "slider", "spinbutton"]);

/**
 * Picks the elements the model should see and groups them by region.
 *
 * Selection runs by priority, then survivors are put back in document order so the printed snapshot
 * still reads like the page.
 */
export function selectCandidates(candidates: readonly InteractiveCandidate[], limits: SnapshotLimits = DEFAULT_LIMITS): SnapshotNode[] {
  const ordered = candidates.map((candidate, order) => ({ candidate, order }));
  const byPriority = [...ordered].sort((left, right) => priority(left.candidate) - priority(right.candidate));
  const seen = new Map<string, number>();
  const kept: { candidate: InteractiveCandidate; order: number }[] = [];
  let links = 0;
  let dropped = 0;
  let repeated = 0;

  for (const entry of byPriority) {
    const { candidate } = entry;
    if (!candidate.rendered || !candidate.enabled) continue;
    if (!isUsable(candidate)) {
      dropped += 1;
      continue;
    }
    if (repeats(seen, candidate) >= limits.maxPerName) {
      repeated += 1;
      continue;
    }
    if ((candidate.role === "link" && links >= limits.maxLinks) || kept.length >= limits.maxElements) {
      dropped += 1;
      continue;
    }
    seen.set(`${candidate.role}|${candidate.name}`, repeats(seen, candidate) + 1);
    if (candidate.role === "link") links += 1;
    kept.push(entry);
  }

  kept.sort((left, right) => left.order - right.order);
  const nodes: SnapshotNode[] = [];
  let region = "";
  for (const { candidate } of kept) {
    if (candidate.regionRole !== "") {
      const groupKey = `${candidate.regionRole}|${candidate.regionName}`;
      if (groupKey !== region) {
        region = groupKey;
        nodes.push({ depth: 0, role: candidate.regionRole, name: candidate.regionName, value: "", state: "", ref: "" });
      }
    }
    nodes.push({
      depth: candidate.regionRole === "" ? 0 : 1,
      role: candidate.role,
      name: candidate.name,
      value: candidate.value,
      state: candidate.state,
      ref: candidate.ref,
    });
  }
  // Declared, never silent: the model has to know the view is partial, and why.
  const notes: string[] = [];
  if (dropped > 0) notes.push(`${dropped} interactive elements over the per-step budget, use mode=markdown or a narrower page`);
  if (repeated > 0) notes.push(`${repeated} repeats collapsed (same role and name more than ${limits.maxPerName} times)`);
  if (notes.length > 0) nodes.push({ depth: 0, role: "text", name: `(${notes.join("; ")})`, value: "", state: "", ref: "" });
  return nodes;
}

/** `e12` -> 12, `f2e12` -> 12; the frame prefix travels in [member InteractiveCandidate.ref]. */
export function refIndex(ref: string): number {
  return Number(/e(\d+)$/.exec(ref)?.[1] ?? -1);
}

/** Frame prefix of a ref: `""` for the main frame, `f2` for the second frame. */
export function refFrame(ref: string): string {
  return /^(f\d+)e\d+$/.exec(ref)?.[1] ?? "";
}

function priority(candidate: InteractiveCandidate): number {
  return ROLE_PRIORITY[candidate.role] ?? 1;
}

function repeats(seen: Map<string, number>, candidate: InteractiveCandidate): number {
  return seen.get(`${candidate.role}|${candidate.name}`) ?? 0;
}

/** An unnamed icon or an empty link costs a line and tells the model nothing. */
function isUsable(candidate: InteractiveCandidate): boolean {
  if (candidate.name !== "") return true;
  if (NAME_OPTIONAL.has(candidate.role)) return true;
  return candidate.value !== "";
}

/**
 * Runs inside the page: every interactable element of one frame in composed-tree order (open shadow
 * roots included), with the facts the filter needs. Must stay self-contained — Playwright serializes
 * this function alone into the page.
 */
export function collectInteractiveCandidates(framePrefix: string): InteractiveCandidate[] {
  // Collection bound, not a display budget: the heaviest page measured so far (wikipedia) produced
  // 1_294 interactable elements, and the filter keeps 300 of them anyway.
  const MAX_CANDIDATES = 4_000;
  const MAX_NAME_CHARS = 120;
  const MAX_REGION_CHARS = 60;
  const MAX_VALUE_CHARS = 120;
  const LANDMARKS: Readonly<Record<string, string>> = { nav: "navigation", main: "main", header: "banner", footer: "contentinfo", aside: "complementary", form: "form", dialog: "dialog" };
  const INTERACTIVE = new Set(["link", "button", "textbox", "searchbox", "checkbox", "radio", "combobox", "listbox", "option", "menuitem", "menuitemcheckbox", "menuitemradio", "tab", "switch", "slider", "spinbutton", "summary", "treeitem"]);
  const SKIP_TAGS = new Set(["script", "style", "noscript", "template", "head", "title", "meta", "link", "svg", "br", "hr"]);
  const PASSWORD_MASK = "••••";
  // Roles whose name comes from their visible text; an input needs its label instead.
  const CONTENT_NAMED = new Set(["link", "button", "option", "menuitem", "menuitemcheckbox", "menuitemradio", "tab", "summary", "treeitem", "checkbox", "radio"]);

  const refs: Element[] = [];
  const candidates: InteractiveCandidate[] = [];
  const store = window as unknown as { __gaiBrowserRefs?: Element[] };
  store.__gaiBrowserRefs = refs;

  const clip = (text: string, limit: number): string => (text.length > limit ? `${text.slice(0, limit)}…` : text);
  const normalize = (raw: string): string => raw.replace(/\s+/g, " ").trim();

  function roleOf(element: Element): string {
    const explicit = normalize(element.getAttribute("role") ?? "").toLowerCase().split(" ")[0] ?? "";
    if (explicit !== "") return explicit;
    const tag = element.tagName.toLowerCase();
    switch (tag) {
      case "a":
        return element.hasAttribute("href") ? "link" : "";
      case "button":
        return "button";
      case "select":
        return element.hasAttribute("multiple") ? "listbox" : "combobox";
      case "textarea":
        return "textbox";
      case "summary":
        return "summary";
      case "option":
        return "option";
      case "input": {
        switch ((element.getAttribute("type") ?? "text").toLowerCase()) {
          case "checkbox":
            return "checkbox";
          case "radio":
            return "radio";
          case "submit":
          case "button":
          case "reset":
          case "image":
          case "file":
            return "button";
          case "hidden":
            return "";
          case "range":
            return "slider";
          case "number":
            return "spinbutton";
          default:
            return "textbox";
        }
      }
      default:
        break;
    }
    return element.hasAttribute("contenteditable") ? "textbox" : "";
  }

  function labelText(element: Element): string {
    const id = element.getAttribute("id");
    if (id !== null && id !== "") {
      const label = element.ownerDocument.querySelector(`label[for="${id.replace(/"/g, '\\"')}"]`);
      if (label !== null) {
        const text = normalize(label.textContent ?? "");
        if (text !== "") return text;
      }
    }
    const wrapping = element.closest("label");
    return wrapping === null ? "" : normalize(wrapping.textContent ?? "");
  }

  /** Name from explicit labelling only — a landmark must never be named after all its children. */
  function explicitName(element: Element): string {
    const labelledBy = normalize(element.getAttribute("aria-labelledby") ?? "");
    if (labelledBy !== "") {
      const parts: string[] = [];
      for (const id of labelledBy.split(" ")) {
        const referenced = element.ownerDocument.getElementById(id);
        if (referenced !== null) parts.push(normalize(referenced.textContent ?? ""));
      }
      const joined = normalize(parts.join(" "));
      if (joined !== "") return joined;
    }
    return normalize(element.getAttribute("aria-label") ?? "") || normalize(element.getAttribute("title") ?? "");
  }

  /**
   * Accessible name in accname order: labelledby/aria-label, then the native label, then the visible
   * text, and only then placeholder/title. `title` before content used to rename every card link
   * after its tooltip, which no longer matched what the accessibility tree reports.
   */
  function accessibleName(element: Element, role: string): string {
    const explicit = explicitName(element);
    if (explicit !== "") return explicit;
    const native = normalize(element.getAttribute("alt") ?? "") || labelText(element);
    if (native !== "") return native;
    const allowedContent = CONTENT_NAMED.has(role);
    const content = allowedContent ? normalize(element.textContent ?? "") : "";
    if (content !== "") return content;
    const placeholder = normalize(element.getAttribute("placeholder") ?? "");
    if (placeholder !== "") return placeholder;
    return normalize(element.getAttribute("title") ?? "");
  }

  function valueOf(element: Element): string {
    if (element instanceof HTMLInputElement) {
      const type = element.type.toLowerCase();
      if (type === "password") return element.value === "" ? "" : PASSWORD_MASK;
      if (type === "checkbox" || type === "radio" || type === "file" || type === "submit") return "";
      return clip(normalize(element.value), MAX_VALUE_CHARS);
    }
    if (element instanceof HTMLTextAreaElement) return clip(normalize(element.value), MAX_VALUE_CHARS);
    if (element instanceof HTMLSelectElement) {
      return clip(normalize(Array.from(element.selectedOptions).map((option) => normalize(option.textContent ?? "")).join(", ")), MAX_VALUE_CHARS);
    }
    return "";
  }

  function stateOf(element: Element): string {
    const states: string[] = [];
    if (element instanceof HTMLInputElement) {
      if (element.indeterminate) states.push("mixed");
      else if (element.type === "checkbox" || element.type === "radio") states.push(element.checked ? "checked" : "unchecked");
      if (element.required) states.push("required");
    }
    const ariaChecked = element.getAttribute("aria-checked");
    if (ariaChecked !== null) states.push(`checked=${ariaChecked}`);
    const ariaExpanded = element.getAttribute("aria-expanded");
    if (ariaExpanded !== null) states.push(`expanded=${ariaExpanded}`);
    if (element.getAttribute("aria-selected") === "true") states.push("selected");
    const ariaPressed = element.getAttribute("aria-pressed");
    if (ariaPressed !== null) states.push(`pressed=${ariaPressed}`);
    return states.join(" ");
  }

  /** Playwright's actionability test: no box, hidden, or no pointer events means not clickable. */
  function isRendered(element: Element, style: CSSStyleDeclaration): boolean {
    if (style.display === "none" || style.visibility !== "visible" || style.pointerEvents === "none" || style.contentVisibility === "hidden") return false;
    const box = element.getBoundingClientRect();
    return box.width > 0 && box.height > 0;
  }

  function collect(element: Element, regionRole: string, regionName: string): void {
    const tag = element.tagName.toLowerCase();
    if (!SKIP_TAGS.has(tag)) {
      const role = roleOf(element);
      if (role !== "" && INTERACTIVE.has(role)) {
        candidates.push({
          role,
          name: clip(accessibleName(element, role), MAX_NAME_CHARS),
          value: valueOf(element),
          state: stateOf(element),
          regionRole,
          regionName,
          rendered: isRendered(element, window.getComputedStyle(element)),
          enabled: element.getAttribute("aria-disabled") !== "true" && !element.matches(":disabled"),
          ref: `${framePrefix}e${refs.length}`,
        });
        refs.push(element);
      }
      const landmark = LANDMARKS[role === "" ? tag : role] ?? LANDMARKS[tag];
      if (landmark !== undefined) {
        regionRole = landmark;
        regionName = clip(explicitName(element), MAX_REGION_CHARS);
      }
    }
    // Shadow content is part of the composed tree, so it is walked where the host sits.
    const shadow = (element as Element & { shadowRoot?: ShadowRoot | null }).shadowRoot;
    if (shadow !== null && shadow !== undefined) {
      for (const child of Array.from(shadow.children)) {
        if (candidates.length >= MAX_CANDIDATES) return;
        collect(child, regionRole, regionName);
      }
    }
    for (const child of Array.from(element.children)) {
      if (candidates.length >= MAX_CANDIDATES) return;
      collect(child, regionRole, regionName);
    }
  }

  const body = document.body ?? document.documentElement;
  if (body !== null) collect(body, "", "");
  return candidates;
}
