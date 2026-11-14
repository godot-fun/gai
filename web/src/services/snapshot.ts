/**
 * Model-facing text of a page snapshot.
 *
 * The page side flattens the visible DOM into a pre-order list of nodes (`depth` carries the tree),
 * because the walk has to happen inside the browser and the formatting has to be unit-testable here.
 * Every actionable node keeps a printed handle (`[e12]`) the agent passes back as `ref`, so the model
 * targets elements by handle instead of guessing CSS selectors.
 */

/** One line of a snapshot. */
export interface SnapshotNode {
  depth: number;
  role: string;
  name: string;
  value: string;
  /** Extra state words such as `checked` or `disabled`; empty when the node has none. */
  state: string;
  /** Handle printed as `[e12]` or `[f2e12]` inside a child frame; empty when not targetable. */
  ref: string;
}

/** Keeps a snapshot inside the budget the agent uses for other tool output. */
export const MAX_SNAPSHOT_CHARS = 24_000;
export const SNAPSHOT_TRUNCATED_SUFFIX = "\n... (snapshot truncated: use mode=markdown, or open a narrower page)";

const EMPTY_PAGE_TEXT = "(page has no readable or interactive content)";

/** Renders nodes as an indented `- role "name" [e1]` list. */
export function formatSnapshot(nodes: readonly SnapshotNode[]): string {
  if (nodes.length === 0) return EMPTY_PAGE_TEXT;
  const lines: string[] = [];
  for (const node of nodes) {
    lines.push(`${"  ".repeat(Math.max(0, node.depth))}- ${describeNode(node)}`);
  }
  return truncateSnapshot(lines.join("\n"));
}

/**
 * Cuts at a line boundary so a truncated snapshot never shows half a node, and reports that it was cut.
 */
export function truncateSnapshot(text: string): string {
  if (text.length <= MAX_SNAPSHOT_CHARS) return text;
  const cut = text.lastIndexOf("\n", MAX_SNAPSHOT_CHARS - SNAPSHOT_TRUNCATED_SUFFIX.length);
  const body = cut > 0 ? text.slice(0, cut) : text.slice(0, MAX_SNAPSHOT_CHARS - SNAPSHOT_TRUNCATED_SUFFIX.length);
  return `${body}${SNAPSHOT_TRUNCATED_SUFFIX}`;
}

function describeNode(node: SnapshotNode): string {
  let line = node.role;
  if (node.name !== "") line += ` "${quote(node.name)}"`;
  if (node.value !== "") line += ` value="${quote(node.value)}"`;
  if (node.state !== "") line += ` (${node.state})`;
  if (node.ref !== "") line += ` [${node.ref}]`;
  return line;
}

/** Collapses whitespace and escapes, so one node always stays on one line. */
function quote(text: string): string {
  return text.replace(/\s+/g, " ").trim().replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}
