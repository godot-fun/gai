import assert from "node:assert/strict";
import { test } from "node:test";
import { DEFAULT_LIMITS, refFrame, refIndex, selectCandidates, type InteractiveCandidate } from "../src/services/interactive";
import { formatSnapshot, type SnapshotNode } from "../src/services/snapshot";

function candidate(overrides: Partial<InteractiveCandidate> = {}): InteractiveCandidate {
  return { role: "link", name: "Docs", value: "", state: "", regionRole: "", regionName: "", rendered: true, enabled: true, ref: "e0", ...overrides };
}

/** The budget marker is a `text` node; element assertions only look at real elements. */
function elements(nodes: readonly SnapshotNode[]): SnapshotNode[] {
  return nodes.filter((node) => node.role !== "text");
}

test("selectCandidates keeps rendered, enabled, named elements", () => {
  const nodes = selectCandidates([
    candidate({ ref: "e0" }),
    candidate({ ref: "e1", rendered: false }),
    candidate({ ref: "e2", enabled: false }),
    candidate({ ref: "e3", name: "" }),
  ]);
  assert.deepEqual(elements(nodes).map((node) => node.name), ["Docs"]);
  assert.equal(elements(nodes)[0]?.ref, "e0");
  // Unrendered and disabled elements are facts, not budget cuts, so only the unnamed link is reported.
  assert.ok(nodes.some((node) => node.name.includes("1 interactive elements over the per-step budget")));
});

test("selectCandidates keeps a nameless form control because its value carries it", () => {
  const nodes = selectCandidates([
    candidate({ role: "textbox", name: "", value: "typed", ref: "e0" }),
    candidate({ role: "combobox", name: "", ref: "e1" }),
    candidate({ role: "button", name: "", ref: "e2" }),
  ]);
  assert.deepEqual(elements(nodes).map((node) => node.role), ["textbox", "combobox"]);
  assert.ok(nodes.some((node) => node.name.includes("1 interactive elements over the per-step budget")));
});

test("selectCandidates collapses repeated navigation and footer links", () => {
  const nodes = selectCandidates([candidate({ ref: "e0" }), candidate({ ref: "e1" }), candidate({ ref: "e2" }), candidate({ ref: "e3" }), candidate({ ref: "e4" })]);
  assert.equal(elements(nodes).length, DEFAULT_LIMITS.maxPerName);
  assert.ok(nodes.some((node) => node.name.includes("3 repeats collapsed")));
});

test("selectCandidates keeps the frame prefix of a handle", () => {
  const nodes = selectCandidates([
    candidate({ ref: "e5", name: "main frame" }),
    candidate({ role: "textbox", ref: "f2e17", name: "inside a frame" }),
  ]);
  assert.deepEqual(elements(nodes).map((node) => node.ref), ["e5", "f2e17"]);
  assert.equal(formatSnapshot(nodes), ['- link "main frame" [e5]', '- textbox "inside a frame" [f2e17]'].join("\n"));
});

test("selectCandidates spends the budget on form controls before links", () => {
  const links = Array.from({ length: 40 }, (_, index) => candidate({ name: `link ${index}`, ref: `e${index}` }));
  const fields = Array.from({ length: 5 }, (_, index) => candidate({ role: "textbox", name: `field ${index}`, ref: `e${100 + index}` }));
  const kept = elements(selectCandidates([...links, ...fields], { maxElements: 10, maxLinks: 40, maxPerName: 2 }));
  assert.equal(kept.length, 10);
  assert.equal(kept.filter((node) => node.role === "textbox").length, 5);
  // Priority decides what survives; document order decides how it prints.
  assert.deepEqual(kept.slice(0, 3).map((node) => node.name), ["link 0", "link 1", "link 2"]);
});

test("selectCandidates gives links their own ceiling", () => {
  const links = Array.from({ length: 20 }, (_, index) => candidate({ name: `link ${index}`, ref: `e${index}` }));
  assert.equal(elements(selectCandidates(links, { maxElements: 100, maxLinks: 5, maxPerName: 2 })).length, 5);
});

test("selectCandidates groups elements under their landmark region", () => {
  const nodes = selectCandidates([
    candidate({ name: "Sign in", regionRole: "banner", ref: "e0" }),
    candidate({ role: "button", name: "Products", regionRole: "navigation", regionName: "Global", ref: "e1" }),
    candidate({ name: "Issues", regionRole: "main", ref: "e2" }),
  ]);
  assert.equal(formatSnapshot(nodes), [
    "- banner",
    '  - link "Sign in" [e0]',
    '- navigation "Global"',
    '  - button "Products" [e1]',
    "- main",
    '  - link "Issues" [e2]',
  ].join("\n"));
});

test("refIndex and refFrame split the frame prefix off a handle", () => {
  assert.equal(refIndex("e12"), 12);
  assert.equal(refIndex("f2e12"), 12);
  assert.equal(refFrame("e12"), "");
  assert.equal(refFrame("f2e12"), "f2");
  assert.equal(refIndex("nonsense"), -1);
});
