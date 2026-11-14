import assert from "node:assert/strict";
import { test } from "node:test";
import { normalizeSearchResults } from "../src/api/search";

test("normalizeSearchResults keeps usable results and numbers them from one", () => {
  const results = normalizeSearchResults([
    { title: "Godot Engine", url: "https://godotengine.org/", snippet: "Free and open source" },
    { title: "Docs", url: "https://docs.godotengine.org/en/stable/", snippet: "" },
  ], 10);
  assert.deepEqual(results, [
    { position: 1, title: "Godot Engine", url: "https://godotengine.org/", snippet: "Free and open source" },
    { position: 2, title: "Docs", url: "https://docs.godotengine.org/en/stable/", snippet: "" },
  ]);
});

test("normalizeSearchResults drops blank and non-http results", () => {
  const results = normalizeSearchResults([
    { title: "", url: "https://example.com/", snippet: "" },
    { title: "no url", url: "", snippet: "" },
    { title: "relative", url: "/search?q=godot", snippet: "" },
    { title: "javascript", url: "javascript:void(0)", snippet: "" },
    { title: "kept", url: "https://example.com/", snippet: "" },
  ], 10);
  assert.deepEqual(results.map((result) => result.title), ["kept"]);
  assert.equal(results[0]?.position, 1);
});

test("normalizeSearchResults dedupes on the normalized url, not the printed href", () => {
  const results = normalizeSearchResults([
    { title: "first", url: "HTTPS://Example.com/Docs", snippet: "" },
    { title: "same target", url: "https://example.com/Docs", snippet: "" },
    { title: "another", url: "https://example.com/other", snippet: "" },
  ], 10);
  assert.deepEqual(results.map((result) => result.title), ["first", "another"]);
  assert.deepEqual(results.map((result) => result.position), [1, 2]);
});

test("normalizeSearchResults stops at the requested count", () => {
  const raw = Array.from({ length: 20 }, (_, index) => ({ title: `result ${index}`, url: `https://example.com/${index}`, snippet: "" }));
  const results = normalizeSearchResults(raw, 3);
  assert.equal(results.length, 3);
  assert.deepEqual(results.map((result) => result.url), ["https://example.com/0", "https://example.com/1", "https://example.com/2"]);
});
