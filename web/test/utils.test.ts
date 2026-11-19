import assert from "node:assert/strict";
import { test } from "node:test";
import { errorMessage, isBlank, isErrorNamed, isOneOf, parseHttpUrl, requireHttpUrl, sanitizeName, trimOrEmpty } from "../src/utils";

test("sanitizeName replaces characters rejected by tool registries", () => {
  assert.equal(sanitizeName("google.drive search/files"), "google_drive_search_files");
  assert.equal(sanitizeName("valid-Name_2"), "valid-Name_2");
});

test("isBlank accepts absent and whitespace-only values", () => {
  assert.equal(isBlank(undefined), true);
  assert.equal(isBlank(" \t\n"), true);
  assert.equal(isBlank(" value "), false);
});

test("trimOrEmpty normalizes optional strings", () => {
  assert.equal(trimOrEmpty(undefined), "");
  assert.equal(trimOrEmpty(" value \n"), "value");
});

test("isOneOf accepts only strings from the provided list", () => {
  const values = ["one", "two"] as const;
  assert.equal(isOneOf("one", values), true);
  assert.equal(isOneOf("three", values), false);
  assert.equal(isOneOf(1, values), false);
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

test("requireHttpUrl returns a URL or throws for an invalid value", () => {
  assert.equal(requireHttpUrl("https://example.com").href, "https://example.com/");
  assert.throws(() => requireHttpUrl("file:///tmp/data"), /absolute http or https URL/);
});
