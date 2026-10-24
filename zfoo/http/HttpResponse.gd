class_name HttpResponse
extends RefCounted


var success: bool = false
## HTTP status code (200, 404, 500, ...); 0 when the request never reached the server, and the code the
## server reported when a failure happened after it answered (a stalled or truncated body).
var code: int = 0
var headers: Dictionary = {}
var body: PackedByteArray = PackedByteArray()
## Why a failed request failed. A transport failure (timeout, DNS, refused, TLS, cancelled) carries
## no status code and no body, so readers must use this text instead of the body.
var error: String = ""


## Builds the response of a request that never reached the server, so callers can return a failed
## response without leaving [member error] empty.
static func failure(message: String) -> HttpResponse:
	var response := HttpResponse.new()
	response.error = message
	return response


func get_body_string() -> String:
	return body.get_string_from_utf8()


func is_redirect() -> bool:
	return code == HTTPClient.RESPONSE_MOVED_PERMANENTLY or code == HTTPClient.RESPONSE_FOUND or code == HTTPClient.RESPONSE_SEE_OTHER \
		or code == HTTPClient.RESPONSE_TEMPORARY_REDIRECT or code == HTTPClient.RESPONSE_PERMANENT_REDIRECT


func get_header(name: String) -> String:
	var lower_name := name.to_lower()
	for header: Variant in headers:
		if str(header).to_lower() == lower_name:
			return str(headers[header]).strip_edges()
	return ""


## Reason text of a failed request: the body when the server answered with one (an API error
## payload such as `401 {"error":{"message":"..."}}`, where [member error] stays empty), otherwise
## [member error] (a transport failure, which has no status code and no body). Never blank.
func get_error_string() -> String:
	var body_text := get_body_string().strip_edges()
	if StringUtils.is_not_blank(body_text):
		return body_text
	if StringUtils.is_not_blank(error):
		return error
	return "no response"


func get_body_json() -> Variant:
	var text := get_body_string()
	if StringUtils.is_blank(text):
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		Log.error("HttpResponse parse JSON failed: {}", json.get_error_message())
		return null
	return json.data


func _to_string() -> String:
	return StringUtils.format("HttpResponse[code:{}, bodySize:{}]", code, body.size())
