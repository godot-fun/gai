import assert from "node:assert/strict";
import { test } from "node:test";
import axios from "axios";
import { loadConfig } from "../src/config";

const config = loadConfig();
const baseUrl = `http://${config.host}:${config.port}`;

test("POST /fetch returns extracted page content", async () => {
  const targetUrl = "https://example.com/";
  const response = await axios.post(`${baseUrl}/fetch`, { url: targetUrl });
  const body = response.data as Record<string, unknown>;
  assert.equal(response.status, 200);
  assert.equal(body.url, targetUrl);
  assert.equal(typeof body.finalUrl, "string");
  assert.equal(typeof body.title, "string");
  assert.equal(body.contentType, "markdown");
  assert.ok(typeof body.content === "string");
  assert.ok(body.content.length > 0);
  assert.equal(typeof body.wordCount, "number");
});
