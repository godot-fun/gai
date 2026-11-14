class_name BrowserStepHelper
extends Object

## Static rules for browser steps: validation, model-JSON coercion, and reply rendering.
##
## Model JSON is untyped, so the `Variant` stops here: a step array becomes [BrowserStep] objects as
## soon as it is validated, and nothing downstream touches loose dictionaries.
##
## Kept apart from [BrowserTool] on purpose: nothing here touches [WebServer], so the rules can be
## unit tested without the local web server, whose static initializer starts the browser.

## One HTTP request carries the whole batch and is bounded by the server timeout, so keep it small.
const MAX_STEPS := 6

## Views [BrowserObserveTool] can read the page in.
const MODE_ELEMENTS := "elements"
const MODE_MARKDOWN := "markdown"
const MODE_SCREENSHOT := "screenshot"
const OBSERVE_MODES: Array[String] = [MODE_ELEMENTS, MODE_MARKDOWN, MODE_SCREENSHOT]


## Outcome of [method normalize_steps]: a usable typed batch, or the reason it was rejected.
class ParseResult extends RefCounted:
	## Empty whenever [member error] is set.
	var steps: Array[BrowserStep] = []
	var error: String = StringUtils.EMPTY

	func is_valid() -> bool:
		return StringUtils.is_blank(error)
	pass


## Validates the model's steps and turns them into typed steps.
## [param raw_steps] is untyped on purpose: a model's JSON array holds Variants, so only the
## per-element `Variant` remains. The caller guarantees it is an array.
static func normalize_steps(raw_steps: Array) -> ParseResult:
	var result := ParseResult.new()
	var items := raw_steps
	if items.is_empty():
		result.error = "error: at least one step is required"
		return result
	if items.size() > MAX_STEPS:
		result.error = StringUtils.format("error: at most {} steps per call, split the work across calls", MAX_STEPS)
		return result

	var steps: Array[BrowserStep] = []
	for index in items.size():
		var entry: Variant = items[index]
		if typeof(entry) != TYPE_DICTIONARY:
			result.error = StringUtils.format("error: steps[{}] must be an object", index)
			return result
		var step := read_step(entry)
		var step_error := validate_step(step, index)
		if StringUtils.is_not_blank(step_error):
			result.error = step_error
			return result
		steps.append(step)
	result.steps = steps
	return result


## Maps one raw JSON object onto the typed step. Unset fields stay blank, unknown fields are dropped.
static func read_step(entry: Dictionary) -> BrowserStep:
	var step := BrowserStep.new()
	step.action = read_string(entry, "action")
	step.url = read_string(entry, "url")
	step.ref = read_string(entry, "ref")
	step.selector = read_string(entry, "selector")
	step.text = read_string(entry, "text")
	step.key = read_string(entry, "key")
	step.value = read_string(entry, "value")
	step.direction = read_string(entry, "direction").to_lower()
	return step


## Field checks that must fail before a step costs a browser action.
static func validate_step(step: BrowserStep, index: int) -> String:
	if not BrowserStep.ACTIONS.has(step.action):
		return StringUtils.format("error: steps[{}].action is not supported action:[{}] allowed:[{}]", index, step.action, ", ".join(BrowserStep.ACTIONS))
	match step.action:
		BrowserStep.ACTION_GOTO:
			if StringUtils.is_blank(step.url):
				return missing_field(index, step.action, "url")
		BrowserStep.ACTION_TYPE:
			if StringUtils.is_blank(step.text):
				return missing_field(index, step.action, "text")
		BrowserStep.ACTION_PRESS:
			if StringUtils.is_blank(step.key):
				return missing_field(index, step.action, "key")
		BrowserStep.ACTION_SELECT:
			if StringUtils.is_blank(step.value):
				return missing_field(index, step.action, "value")
		BrowserStep.ACTION_SCROLL:
			if StringUtils.is_not_blank(step.direction) and step.direction != BrowserStep.DIRECTION_UP and step.direction != BrowserStep.DIRECTION_DOWN:
				return StringUtils.format("error: steps[{}].direction must be {} or {}, got: [{}]", index, BrowserStep.DIRECTION_UP, BrowserStep.DIRECTION_DOWN, step.direction)
		_:
			pass
	if BrowserStep.is_targeted(step.action) and StringUtils.is_blank(step.ref) and StringUtils.is_blank(step.selector):
		return StringUtils.format("error: steps[{}] {} needs a ref from the last snapshot, or a selector", index, step.action)
	return StringUtils.EMPTY


## Model-facing text: the failure first, then where the page ended up, then the snapshot.
static func describe(response: BrowserResult) -> String:
	var build := StringBuilder.new()
	if StringUtils.is_not_blank(response.error):
		build.append_line("error: " + response.error)
		build.append_line()
	build.append_line(StringUtils.format("url: {}", response.url))
	build.append_line(StringUtils.format("title: {}", response.title))
	if StringUtils.is_not_blank(response.snapshot):
		build.append_line()
		build.append(response.snapshot)
	if StringUtils.is_not_blank(response.markdown):
		build.append_line()
		build.append_line("markdown:")
		build.append(response.markdown)
	if StringUtils.is_not_blank(response.screenshotPath):
		build.append_line(FileUtils.NEWLINE_LF + StringUtils.format("screenshot: {} (use read_image to view it)", response.screenshotPath))
	elif StringUtils.is_not_blank(response.screenshotError):
		build.append_line(FileUtils.NEWLINE_LF + "screenshot failed: " + response.screenshotError)
	return StringUtils.truncate(build.build_string().strip_edges(), AgentTool.MAX_OUTPUT, AgentTool.TRUNCATED_SUFFIX)


static func missing_field(index: int, action: String, field: String) -> String:
	return StringUtils.format("error: steps[{}] {} needs a non-empty {}", index, action, field)


## Raw model values are JSON: a key can be missing, `null`, or even a number for a text field.
## Everything a step carries is text on the wire, so the coercion lives here instead of at eight
## call sites — and `str(null)` would otherwise become the literal text "<null>".
static func read_string(entry: Dictionary, field: String) -> String:
	var raw: Variant = entry.get(field, StringUtils.EMPTY)
	return StringUtils.EMPTY if raw == null else str(raw).strip_edges()


## Validates `browser_observe`'s mode. A blank mode means the default; an unsupported one returns
## an empty string so the caller can report it with the raw value.
static func normalize_mode(raw_mode: String) -> String:
	var mode := raw_mode.strip_edges().to_lower()
	if StringUtils.is_blank(mode):
		return MODE_ELEMENTS
	return mode if OBSERVE_MODES.has(mode) else StringUtils.EMPTY


## The single step that reads the page in [param mode]: page text, or the element tree that a
## screenshot also needs as a no-op read.
static func observe_steps(mode: String) -> Array[BrowserStep]:
	var steps: Array[BrowserStep] = [BrowserStep.create(BrowserStep.ACTION_MARKDOWN if mode == MODE_MARKDOWN else BrowserStep.ACTION_SNAPSHOT)]
	return steps
