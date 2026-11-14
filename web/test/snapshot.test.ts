import assert from "node:assert/strict";
import { test } from "node:test";
import { formatSnapshot, MAX_SNAPSHOT_CHARS, SNAPSHOT_TRUNCATED_SUFFIX, truncateSnapshot, type SnapshotNode } from "../src/services/snapshot";

function node(overrides: Partial<SnapshotNode>): SnapshotNode {
  return { depth: 0, role: "button", name: "", value: "", state: "", ref: "", ...overrides };
}

test("formatSnapshot indents nodes and prints the refs the agent targets", () => {
  const text = formatSnapshot([
    node({ role: "navigation" }),
    node({ role: "link", name: "Learn more", depth: 1, ref: "e0" }),
    node({ role: "heading", name: "Sign in", depth: 1, state: "level=1" }),
    node({ role: "textbox", name: "Email", value: "a@b.com", depth: 2, ref: "e1" }),
  ]);
  assert.equal(
    text,
    [
      "- navigation",
      '  - link "Learn more" [e0]',
      '  - heading "Sign in" (level=1)',
      '    - textbox "Email" value="a@b.com" [e1]',
    ].join("\n"),
  );
});

test("formatSnapshot keeps every node on one line", () => {
  const text = formatSnapshot([node({ name: 'multi\nline\t"quoted"', value: "a  b" })]);
  assert.equal(text, '- button "multi line \\"quoted\\"" value="a b"');
});

test("formatSnapshot reports a page without content instead of an empty string", () => {
  assert.equal(formatSnapshot([]), "(page has no readable or interactive content)");
});

test("formatSnapshot never exceeds the tool output budget", () => {
  const nodes: SnapshotNode[] = [];
  for (let index = 0; index < 400; index += 1) nodes.push(node({ role: "link", name: `item ${index} ${"x".repeat(120)}`, depth: 1, ref: `e${index}` }));
  const text = formatSnapshot(nodes);
  assert.ok(text.length <= MAX_SNAPSHOT_CHARS + SNAPSHOT_TRUNCATED_SUFFIX.length);
  assert.ok(text.endsWith(SNAPSHOT_TRUNCATED_SUFFIX));
});

test("truncateSnapshot cuts at a line boundary and leaves short text alone", () => {
  assert.equal(truncateSnapshot("short"), "short");
  const lines: string[] = [];
  for (let index = 0; index < 3_000; index += 1) lines.push(`- link "line ${index}"`);
  const cut = truncateSnapshot(lines.join("\n"));
  assert.ok(cut.endsWith(SNAPSHOT_TRUNCATED_SUFFIX));
  const body = cut.slice(0, -SNAPSHOT_TRUNCATED_SUFFIX.length);
  assert.ok(body.length <= MAX_SNAPSHOT_CHARS);
  assert.ok(/^- link "line \d+"$/m.test(body.split("\n").at(-1) ?? ""));
});
