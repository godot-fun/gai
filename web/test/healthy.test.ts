import assert from "node:assert/strict";
import { test } from "node:test";
import { baseUrl, client } from "./server-client";

test("GET /healthy reports browser readiness", async () => {
  const response = await client.get(`${baseUrl}/healthy`);
  const body = response.data as Record<string, unknown>;
  assert.equal(response.status, 200);
  assert.equal(body.status, "ok");
  assert.equal(body.browser, "ready");
  assert.equal(typeof body.uptimeSeconds, "number");
});
