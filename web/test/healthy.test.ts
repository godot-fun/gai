import assert from "node:assert/strict";
import { test } from "node:test";
import axios from "axios";
import { loadConfig } from "../src/config";

const config = loadConfig();
const baseUrl = `http://${config.host}:${config.port}`;

test("GET /healthy reports browser readiness", async () => {
  const response = await axios.get(`${baseUrl}/healthy`);
  const body = response.data as Record<string, unknown>;
  assert.equal(response.status, 200);
  assert.equal(body.status, "ok");
  assert.equal(body.browser, "ready");
  assert.equal(typeof body.uptimeSeconds, "number");
});
