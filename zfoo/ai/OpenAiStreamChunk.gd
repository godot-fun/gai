class_name OpenAiStreamChunk
extends RefCounted


class StreamDelta:
	var role: String = ""
	var content: String = ""
	var reasoning_content: String = ""
	var tool_calls: Array[ToolCall.StreamDelta] = []
	pass


class Choice:
	var index: int = 0
	var delta: StreamDelta = StreamDelta.new()
	var finish_reason: String = ""
	pass


var id: String = ""
var model: String = ""
var choices: Array[Choice] = []
var usage: OpenAiUsage = OpenAiUsage.new()
