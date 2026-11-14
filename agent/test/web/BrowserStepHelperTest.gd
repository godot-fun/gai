## Offline tests for [BrowserStepHelper]: step validation, JSON coercion, and reply rendering.
## No browser and no server needed.

func normalize_steps_accepts_a_batch_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([
		{"action": "click", "ref": "e3"},
		{"action": "type", "ref": "e4", "text": "hello", "unexpected": "dropped"},
	])
	assert(batch.is_valid())
	assert(batch.steps.size() == 2)
	assert(batch.steps[0].action == BrowserStep.ACTION_CLICK)
	assert(batch.steps[0].ref == "e3")
	assert(batch.steps[1].text == "hello")
	assert(StringUtils.is_blank(batch.steps[1].selector))
	pass


func normalize_steps_accepts_a_selector_instead_of_a_ref_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([{"action": "click", "selector": "#submit"}])
	assert(batch.is_valid())
	assert(batch.steps[0].selector == "#submit")
	assert(StringUtils.is_blank(batch.steps[0].ref))
	pass


## `scroll` always moves one viewport, so only the direction survives: an unknown field and a
## stray distance from an older caller are dropped instead of being forwarded.
func normalize_steps_coerces_direction_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([
		{"action": "scroll", "direction": "UP"},
		{"action": "scroll", "amount": "-400"},
	])
	assert(batch.is_valid())
	assert(batch.steps[0].direction == BrowserStep.DIRECTION_UP)
	assert(StringUtils.is_blank(batch.steps[1].direction))
	assert(not batch.steps[1].to_dict().has("amount"))
	pass


func normalize_steps_rejects_a_malformed_batch_test() -> void:
	# A non-array is rejected by BrowserActTool before it reaches here, which is untyped tool args.
	assert(StringUtils.is_not_blank(BrowserStepHelper.normalize_steps([]).error))
	assert(StringUtils.is_not_blank(BrowserStepHelper.normalize_steps(["click"]).error))
	var too_many: Array = []
	for index in BrowserStepHelper.MAX_STEPS + 1:
		too_many.append({"action": "snapshot"})
	assert(StringUtils.is_not_blank(BrowserStepHelper.normalize_steps(too_many).error))
	pass


func normalize_steps_rejects_an_unknown_action_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([{"action": "evaluate", "text": "alert(1)"}])
	assert(not batch.is_valid())
	assert(batch.error.contains("evaluate"))
	assert(batch.steps.is_empty())
	pass


func normalize_steps_reports_the_missing_field_test() -> void:
	assert(BrowserStepHelper.normalize_steps([{"action": "goto"}]).error.contains("url"))
	assert(BrowserStepHelper.normalize_steps([{"action": "type", "ref": "e1"}]).error.contains("text"))
	assert(BrowserStepHelper.normalize_steps([{"action": "press"}]).error.contains("key"))
	assert(BrowserStepHelper.normalize_steps([{"action": "select", "ref": "e1"}]).error.contains("value"))
	assert(BrowserStepHelper.normalize_steps([{"action": "click"}]).error.contains("ref"))
	assert(BrowserStepHelper.normalize_steps([{"action": "scroll", "direction": "left"}]).error.contains("direction"))
	assert(BrowserStepHelper.normalize_steps([{"action": "scroll"}]).is_valid())
	pass


func step_payload_only_carries_the_fields_that_are_set_test() -> void:
	var click := BrowserStep.create(BrowserStep.ACTION_CLICK)
	click.ref = "e3"
	var data := click.to_dict()
	assert(data.size() == 2)
	assert(data["action"] == BrowserStep.ACTION_CLICK)
	assert(data["ref"] == "e3")
	assert(not data.has("text"))

	var scroll := BrowserStep.create(BrowserStep.ACTION_SCROLL)
	scroll.direction = BrowserStep.DIRECTION_UP
	assert(scroll.to_dict().size() == 2)
	assert(scroll.to_dict()["direction"] == BrowserStep.DIRECTION_UP)
	assert(StringUtils.is_blank(BrowserStep.create(BrowserStep.ACTION_RELOAD).to_dict().get("ref", "")))
	pass


func describe_puts_the_failure_first_test() -> void:
	var response := BrowserResult.new()
	response.ok = false
	response.url = "https://example.com/"
	response.title = "Example"
	response.error = "click failed: ref e9 is stale"
	response.snapshot = "- link \"Learn more\" [e0]"
	var text := BrowserStepHelper.describe(response)
	assert(text.begins_with("error: click failed: ref e9 is stale"))
	assert(text.contains("url: https://example.com/"))
	assert(text.contains("title: Example"))
	assert(text.contains("[e0]"))
	assert(not text.contains("screenshot"))
	pass


func describe_reports_the_screenshot_path_test() -> void:
	var response := BrowserResult.new()
	response.ok = true
	response.url = "https://example.com/"
	response.title = "Example"
	response.snapshot = "- link \"Learn more\" [e0]"
	response.screenshotPath = "C:/cache/browser_1.webp"
	assert(BrowserStepHelper.describe(response).contains("screenshot: C:/cache/browser_1.webp"))
	response.screenshotPath = StringUtils.EMPTY
	response.screenshotError = "target closed"
	assert(BrowserStepHelper.describe(response).contains("screenshot failed: target closed"))
	pass


func describe_without_a_snapshot_test() -> void:
	var response := BrowserResult.new()
	response.ok = true
	response.url = "about:blank"
	response.title = StringUtils.EMPTY
	assert(BrowserStepHelper.describe(response) == "url: about:blank\ntitle:")
	pass


## The wire contract with `POST /browser/action`, checked without a running server.
func browser_wire_format_test() -> void:
	var click := BrowserStep.create(BrowserStep.ACTION_CLICK)
	click.ref = "e3"
	var steps: Array[BrowserStep] = [click]
	var payload: Dictionary = JSON.parse_string(JsonUtils.object_to_json({"steps": steps, "snapshot": true}))
	assert(payload.snapshot == true)
	assert(payload.steps.size() == 1)
	assert(payload.steps[0].action == "click")
	assert(payload.steps[0].ref == "e3")
	assert(not payload.steps[0].has("text"))

	var body := "{\"ok\":false,\"action\":\"click\",\"url\":\"https://example.com/\",\"title\":\"Example\",\"error\":\"click failed: ref e9 is stale\",\"snapshot\":\"- link \\\"Learn more\\\" [e0]\",\"screenshotPath\":\"\",\"screenshotError\":\"\"}"
	var response: BrowserResult = JsonUtils.json_to_object(body, BrowserResult)
	assert(response != null)
	assert(not response.ok)
	assert(response.url == "https://example.com/")
	assert(response.title == "Example")
	assert(response.error.contains("stale"))
	assert(response.snapshot.contains("[e0]"))
	pass


## `wait` is gone: the server settles the document, so a blind sleep only wastes wall-clock time.
## `back`, `forward`, and `reload` stay because synthetic keys never reach the browser chrome.
func wait_step_is_rejected_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([{"action": "wait", "milliseconds": 500}])
	assert(not batch.is_valid())
	assert(batch.error.contains("wait"))
	assert(BrowserStepHelper.normalize_steps([{"action": "back"}]).is_valid())
	assert(BrowserStepHelper.normalize_steps([{"action": "forward"}]).is_valid())
	assert(BrowserStepHelper.normalize_steps([{"action": "reload"}]).is_valid())
	pass


## `browser_observe` asks for one view at a time; the element tree is the default.
func observe_mode_selects_one_view_test() -> void:
	assert(BrowserStepHelper.normalize_mode(StringUtils.EMPTY) == BrowserStepHelper.MODE_ELEMENTS)
	assert(BrowserStepHelper.normalize_mode("MARKDOWN") == BrowserStepHelper.MODE_MARKDOWN)
	assert(BrowserStepHelper.normalize_mode(" screenshot ") == BrowserStepHelper.MODE_SCREENSHOT)
	assert(StringUtils.is_blank(BrowserStepHelper.normalize_mode("dom")))
	assert(BrowserStepHelper.observe_steps(BrowserStepHelper.MODE_MARKDOWN)[0].action == BrowserStep.ACTION_MARKDOWN)
	assert(BrowserStepHelper.observe_steps(BrowserStepHelper.MODE_ELEMENTS)[0].action == BrowserStep.ACTION_SNAPSHOT)
	assert(BrowserStepHelper.observe_steps(BrowserStepHelper.MODE_SCREENSHOT)[0].action == BrowserStep.ACTION_SNAPSHOT)
	assert(BrowserStepHelper.normalize_steps([{"action": BrowserStep.ACTION_MARKDOWN}]).is_valid())
	pass


func describe_labels_the_markdown_test() -> void:
	var response := BrowserResult.new()
	response.ok = true
	response.url = "https://example.com/docs"
	response.title = "Docs"
	response.markdown = "# Title\n\nbody text"
	var text := BrowserStepHelper.describe(response)
	assert(text.contains("url: https://example.com/docs"))
	assert(text.contains("markdown:\n# Title"))
	assert(not text.contains("(page has no readable"))
	pass


## A model can send `null` or a number for an optional field; both must read as "not set" rather
## than as the literal text "<null>", which used to pass validation and fail at the server.
func normalize_steps_treats_null_as_absent_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([{"action": "click", "ref": null, "text": null}])
	assert(not batch.is_valid())
	assert(batch.error.contains("ref"))
	assert(not batch.error.contains("<null>"))
	var number_batch := BrowserStepHelper.normalize_steps([{"action": "type", "ref": "e1", "text": 42}])
	assert(number_batch.is_valid())
	assert(number_batch.steps[0].text == "42")
	pass


## The action decides which fields exist: applying a field to a step that has no use for it must not
## forward it to the server.
func read_step_keeps_only_the_fields_of_its_action_test() -> void:
	var batch := BrowserStepHelper.normalize_steps([
		{"action": "click", "ref": "e3", "text": "not used by click", "value": "nor this"},
		{"action": "goto", "ref": "e9", "url": "https://example.com"},
		{"action": "type", "ref": "e4", "text": "hello"},
	])
	assert(batch.is_valid())
	assert(batch.steps[0].to_dict().size() == 2)
	assert(not batch.steps[0].to_dict().has("text"))
	assert(not batch.steps[0].to_dict().has("value"))
	assert(batch.steps[1].to_dict().size() == 2)
	assert(not batch.steps[1].to_dict().has("ref"))
	assert(batch.steps[2].text == "hello")
	pass
