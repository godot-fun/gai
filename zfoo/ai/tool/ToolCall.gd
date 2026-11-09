class_name ToolCall
extends RefCounted

## Tool call on an assistant message (request history or completion result).


class Function:
	var name: String = ""
	var arguments: String = ""
	pass


## SSE stream fragment (`choices[].delta.tool_calls[]`).
class StreamDelta:
	var index: int = 0
	var id: String = ""
	var type: String = ToolDef.TYPE_FUNCTION
	var function: Function = Function.new()
	pass


var id: String = ""
var type: String = ToolDef.TYPE_FUNCTION
var function: Function = Function.new()


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

static func parse_json(json: String) -> ToolCall:
	return JsonUtils.json_to_object(json, ToolCall)


static func parse(raw: Variant) -> ToolCall:
	if raw is ToolCall:
		return raw
	if typeof(raw) == TYPE_DICTIONARY:
		return JsonUtils.dict_to_object(raw, ToolCall)
	return null


static func parse_list(raw: Variant) -> Array[ToolCall]:
	var result: Array[ToolCall] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item: Variant in raw:
		var call := parse(item)
		if call != null:
			result.append(call)
	return result


static func merge_stream_deltas(acc: Array[ToolCall], deltas: Variant) -> void:
	if typeof(deltas) != TYPE_ARRAY:
		return
	for raw: Variant in deltas:
		var delta: StreamDelta = null
		if raw is StreamDelta:
			delta = raw
		elif typeof(raw) == TYPE_DICTIONARY:
			delta = JsonUtils.dict_to_object(raw, StreamDelta)
		if delta == null:
			continue
		merge_stream_delta(acc, delta)


static func merge_stream_delta(acc: Array[ToolCall], delta: StreamDelta) -> void:
	var index := delta.index
	while acc.size() <= index:
		acc.append(ToolCall.new())
	var entry := acc[index]
	if StringUtils.is_not_empty(delta.id):
		entry.id = delta.id
	if StringUtils.is_not_empty(delta.type):
		entry.type = delta.type
	if StringUtils.is_not_empty(delta.function.name):
		entry.function.name = delta.function.name
	if StringUtils.is_not_empty(delta.function.arguments):
		entry.function.arguments += delta.function.arguments


# ---------------------------------------------------------------------------
# Deep clone
# ---------------------------------------------------------------------------

func deep_clone() -> ToolCall:
	var cloned := ToolCall.new()
	cloned.id = id
	cloned.type = type
	cloned.function.name = function.name
	cloned.function.arguments = function.arguments
	return cloned
