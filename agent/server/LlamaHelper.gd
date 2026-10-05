class_name LlamaHelper
extends Object

class Token extends RefCounted:
	var id: int
	var piece: String


	func _init(token_id: int, token_piece: String) -> void:
		id = token_id
		piece = token_piece
		pass
	pass


class TokenizeResult extends RefCounted:
	var tokens: Array[Token] = []
	var total_tokens: int = 0
	pass


## Returns whether the llama-server health endpoint reports a ready status.
static func async_health(server_url: String) -> bool:
	var response := await HttpHelper.async_get(server_url.trim_suffix("/") + "/health", TimeUtils.MILLIS_PER_SECOND)
	var data: Variant = response.get_body_json() if response.code == 200 else null
	return typeof(data) == TYPE_DICTIONARY and data.get("status", "") == "ok"


## Returns each token's strongly typed ID and piece, plus the total token count.
static func async_tokenize(server_url: String, prompt: String) -> TokenizeResult:
	var result := TokenizeResult.new()
	var payload := {
		"content": prompt,
		"add_special": false,
		"parse_special": true,
		"with_pieces": true,
	}
	var response := await HttpHelper.async_post(server_url.trim_suffix("/") + "/tokenize", JSON.stringify(payload))
	if not response.success:
		Log.error("llama tokenize failed code:[{}] body:[{}]", response.code, response.get_body_string())
		return result
	var data: Variant = response.get_body_json()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("tokens", null)) != TYPE_ARRAY:
		Log.error("llama tokenize returned invalid JSON")
		return result
	for raw_token: Dictionary in data.get("tokens", []):
		var raw_piece: Variant = raw_token.get("piece", "")
		var piece := decode_piece(raw_piece)
		result.tokens.append(Token.new(int(raw_token.get("id", -1)), piece))
	result.total_tokens = result.tokens.size()
	return result


## llama.cpp returns invalid UTF-8 token fragments as byte arrays; preserve them as text when possible.
static func decode_piece(raw_piece: Variant) -> String:
	if raw_piece is String:
		return raw_piece
	if raw_piece is Array:
		var bytes := PackedByteArray()
		for value: Variant in raw_piece:
			bytes.append(int(value))
		return bytes.get_string_from_utf8()
	return str(raw_piece)
