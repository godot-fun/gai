extends Node


@onready var chatButton: Button = $ChatRequest
@onready var chatStreamButton: Button = $ChatStreamRequest

const PROMPT := "Introduce godot-framework in one sentence."


func _ready() -> void:
	chatButton.pressed.connect(on_chat_pressed)
	chatStreamButton.pressed.connect(on_chat_stream_pressed)
	pass


func on_chat_pressed() -> void:
	var client := ApiSetting.get_client()
	var text := await client.async_chat_text(PROMPT)
	if StringUtils.is_blank(text):
		Log.error("OpenAI returned empty text")
		return
	Log.info("OpenAI reply:[{}]", text)
	pass


func on_chat_stream_pressed() -> void:
	var client := ApiSetting.get_client()
	var messages: Array[ChatMessage] = [ChatMessage.user(PROMPT)]
	var completion := await client.async_chat_messages_stream(
		messages,
		[],
			"",
		func(delta: String, stream_kind: String) -> void:
			Log.info("OpenAI delta:[{}]", delta)
	)
	if completion.has_error() or StringUtils.is_blank(completion.content):
		Log.error("OpenAI stream returned empty text")
		return
	Log.info("OpenAI stream reply:[{}]", completion.content)
	pass
