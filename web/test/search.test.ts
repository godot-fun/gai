import assert from "node:assert/strict";
import { test } from "node:test";
import { baseUrl, client } from "./server-client";

test("POST /search returns web search results", async () => {
  const response = await client.post(`${baseUrl}/search`, { query: "Godot Engine", count: 5 });
  const body = response.data as { query?: unknown; results?: unknown; screenshotPath?: unknown; screenshotError?: unknown };
  assert.equal(response.status, 200);
  assert.equal(body.query, "Godot Engine");
  assert.ok(Array.isArray(body.results));
  assert.equal(body.screenshotPath, "");
  assert.equal(body.screenshotError, "");
  assert.ok(body.results.length > 0);
  for (const result of body.results) {
    assert.equal(typeof result.position, "number");
    assert.equal(typeof result.title, "string");
    assert.equal(typeof result.url, "string");
    assert.equal(typeof result.snippet, "string");
  }
});

test("POST /search rejects a missing or non-numeric count before opening a page", async () => {
  const missing = await client.post(`${baseUrl}/search`, { query: "Godot Engine" }, { validateStatus: () => true });
  assert.equal(missing.status, 400);
  assert.equal(missing.data.error.code, "INVALID_REQUEST");

  const notANumber = await client.post(`${baseUrl}/search`, { query: "Godot Engine", count: "5" }, { validateStatus: () => true });
  assert.equal(notANumber.status, 400);
  assert.equal(notANumber.data.error.code, "INVALID_REQUEST");
});
