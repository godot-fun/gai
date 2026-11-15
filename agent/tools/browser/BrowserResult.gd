class_name BrowserResult
extends RefCounted

## Common reply of the browser endpoints. Only observation fills snapshot or Markdown; actions
## always fill the screenshot fields.
##
## Named after the `BrowserResult` interface it deserializes (see web/src/services/browser-session.ts),
## and kept in its own file so the browser tools can be tested without the static initializer of
## [WebServer], which starts the local server.

var ok: bool
var url: String
var title: String
var error: String
var snapshot: String
## Readable Markdown of the live page; only a markdown observation fills it.
var markdown: String
var screenshotPath: String
var screenshotError: String
