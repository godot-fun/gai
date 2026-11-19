import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpError, optionalPositiveNumber, optionalString, requireString } from "../src/http";

test("requireString accepts a non-blank string", () => {
  assert.equal(requireString("value", "field"), "value");
});

test("requireString rejects missing or blank strings", () => {
  assert.throws(() => requireString(undefined, "field"), HttpError);
  assert.throws(() => requireString("   ", "field"), HttpError);
  assert.throws(() => requireString(1, "field"), HttpError);
});

test("optionalString keeps undefined and returns string values", () => {
  assert.equal(optionalString(undefined, "field"), undefined);
  assert.equal(optionalString("", "field"), "");
  assert.equal(optionalString("value", "field"), "value");
});

test("optionalString rejects non-string values", () => {
  assert.throws(() => optionalString(null, "field"), HttpError);
  assert.throws(() => optionalString(1, "field"), HttpError);
});

test("optionalPositiveNumber accepts undefined and positive finite numbers", () => {
  assert.equal(optionalPositiveNumber(undefined, "duration"), undefined);
  assert.equal(optionalPositiveNumber(15, "duration"), 15);
  assert.equal(optionalPositiveNumber(0.25, "duration"), 0.25);
});

test("optionalPositiveNumber rejects invalid durations", () => {
  for (const value of [null, "15", 0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.throws(() => optionalPositiveNumber(value, "duration"), HttpError);
  }
});
