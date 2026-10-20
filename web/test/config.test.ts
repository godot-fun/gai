import assert from "node:assert/strict";
import { test } from "node:test";
import { config, isProxyEnabled } from "../src/config";

test("isProxyEnabled reports whether a proxy address is configured", () => {
  const originalProxy = config.proxy;
  try {
    config.proxy = "";
    assert.equal(isProxyEnabled(), false);

    config.proxy = "http://127.0.0.1:10809";
    assert.equal(isProxyEnabled(), true);
  } finally {
    config.proxy = originalProxy;
  }
});
