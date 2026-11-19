import assert from "node:assert/strict";
import { test } from "node:test";
import { errorMessage, isBlank, isErrorNamed, parseHttpUrl, sanitizeName } from "../src/utils";

test("sanitizeName replaces characters rejected by tool registries", () => {
  assert.equal(sanitizeName("google.drive search/files"), "google_drive_search_files");
  assert.equal(sanitizeName("valid-Name_2"), "valid-Name_2");
});

test("isBlank accepts absent and whitespace-only values", () => {
  assert.equal(isBlank(undefined), true);
  assert.equal(isBlank(" \t\n"), true);
  assert.equal(isBlank(" value "), false);
});

test("errorMessage reads Errors and safely stringifies other thrown values", () => {
  assert.equal(errorMessage(new Error("broken")), "broken");
  assert.equal(errorMessage("broken"), "broken");
  assert.equal(errorMessage(null), "null");
});

test("isErrorNamed only accepts Errors with the requested name", () => {
  const timeout = new Error("late");
  timeout.name = "TimeoutError";
  assert.equal(isErrorNamed(timeout, "TimeoutError"), true);
  assert.equal(isErrorNamed("TimeoutError", "TimeoutError"), false);
});

test("parseHttpUrl accepts and normalizes absolute HTTP URLs", () => {
  assert.equal(parseHttpUrl(" HTTPS://Example.com/path ")?.href, "https://example.com/path");
});

test("parseHttpUrl rejects malformed, relative, and non-HTTP URLs", () => {
  assert.equal(parseHttpUrl("not a url"), null);
  assert.equal(parseHttpUrl("/relative"), null);
  assert.equal(parseHttpUrl("file:///tmp/data"), null);
});
