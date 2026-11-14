class_name BrowserResult
extends RefCounted

## Reply of `POST /browser/action`: the page after the steps ran, a fresh snapshot, and the reason
## when a step failed.
##
## Named after the `BrowserResult` interface it deserializes (see web/src/services/browser-session.ts),
## and kept in its own file so the browser tools can be tested without the static initializer of
## [WebServer], which starts the local server.

var ok: bool
var url: String
var title: String
var error: String
var snapshot: String
## Readable Markdown of the live page; only a `markdown` step fills it.
var markdown: String
var screenshotPath: String
var screenshotError: String
