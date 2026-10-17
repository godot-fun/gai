import assert from "node:assert/strict";
import { test } from "node:test";
import axios from "axios";
import { loadConfig } from "../src/config";

const config = loadConfig();
const baseUrl = `http://${config.host}:${config.port}`;

test("POST /search returns Bing search results", async () => {
  const response = await axios.post(`${baseUrl}/search`, { query: "Godot Engine", count: 5 });
  const body = response.data as { query?: unknown; results?: unknown };
  assert.equal(response.status, 200);
  assert.equal(body.query, "Godot Engine");
  assert.ok(Array.isArray(body.results));
  assert.ok(body.results.length > 0);
  for (const result of body.results) {
    assert.equal(typeof result.position, "number");
    assert.equal(typeof result.title, "string");
    assert.equal(typeof result.url, "string");
    assert.equal(typeof result.snippet, "string");
  }
});
