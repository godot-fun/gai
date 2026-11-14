class_name BrowserStep
extends IJsonSerializable

## One step of `POST /browser/action`.
##
## Typed counterpart of the raw model JSON, so the tool layer never passes loose dictionaries and
## the server contract lives in one place. Only the fields a step sets are serialized: the server
## reads an absent field as "not requested", and a stray `ref: ""` would make it look for an element
## instead of typing into the focused one.
##
## History and reload keep their own actions: synthetic key events stop at the content process, so
## `Alt+Left` or `Ctrl+R` never reach Firefox's browser chrome. Waiting is not an action at all —
## the server settles the document before it snapshots.

const ACTION_GOTO := "goto"
const ACTION_SNAPSHOT := "snapshot"
## Page text as Markdown, read from the live page rather than from a fresh fetch of its URL.
const ACTION_MARKDOWN := "markdown"
const ACTION_CLICK := "click"
const ACTION_TYPE := "type"
const ACTION_PRESS := "press"
const ACTION_HOVER := "hover"
const ACTION_SELECT := "select"
const ACTION_SCROLL := "scroll"
const ACTION_BACK := "back"
const ACTION_FORWARD := "forward"
const ACTION_RELOAD := "reload"

const ACTIONS: PackedStringArray = [ACTION_GOTO, ACTION_SNAPSHOT, ACTION_MARKDOWN, ACTION_CLICK, ACTION_TYPE, ACTION_PRESS, ACTION_HOVER, ACTION_SELECT, ACTION_SCROLL, ACTION_BACK, ACTION_FORWARD, ACTION_RELOAD]
## Actions that need an element handle from the last snapshot (or an explicit selector).
const TARGETED_ACTIONS: PackedStringArray = [ACTION_CLICK, ACTION_TYPE, ACTION_HOVER, ACTION_SELECT]

const DIRECTION_UP := "up"
const DIRECTION_DOWN := "down"

var action: String = StringUtils.EMPTY
var url: String = StringUtils.EMPTY
## Handle printed by a snapshot, e.g. `e12`.
var ref: String = StringUtils.EMPTY
## Playwright selector, used when [member ref] is blank.
var selector: String = StringUtils.EMPTY
var text: String = StringUtils.EMPTY
var key: String = StringUtils.EMPTY
var value: String = StringUtils.EMPTY
## [constant DIRECTION_UP] or [constant DIRECTION_DOWN]; blank means down. `scroll` always
## moves one viewport, so there is no distance to configure.
var direction: String = StringUtils.EMPTY


static func create(step_action: String) -> BrowserStep:
	var step := BrowserStep.new()
	step.action = step_action
	return step


## True when the step targets an element rather than the page.
static func is_targeted(step_action: String) -> bool:
	return TARGETED_ACTIONS.has(step_action)


## Wire payload: only the fields that are set, so "absent" stays distinguishable from "empty".
## Fields are listed one by one on purpose: each line is the wire contract and stays greppable.
func to_dict() -> Dictionary[String, Variant]:
	var data: Dictionary[String, Variant] = {"action": action}
	set_if_not_blank(data, "url", url)
	set_if_not_blank(data, "ref", ref)
	set_if_not_blank(data, "selector", selector)
	set_if_not_blank(data, "text", text)
	set_if_not_blank(data, "key", key)
	set_if_not_blank(data, "value", value)
	set_if_not_blank(data, "direction", direction)
	return data


## A blank field means "not requested": the server reads a missing key that way, and a stray
## `ref: ""` would make it look for an element instead of typing into the focused one.
static func set_if_not_blank(data: Dictionary[String, Variant], field: String, value: String) -> void:
	if StringUtils.is_not_blank(value):
		data[field] = value
	pass


func serialize() -> String:
	return JsonUtils.object_to_json(to_dict())
