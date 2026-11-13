## Offline tests for the plain-HTTP fallback helpers: payload type filtering, the closed-connection
## tolerance, and the body size cap. No network, no browser.

func is_text_payload_test() -> void:
	assert(WebFallback.is_text_payload("text/html; charset=utf-8"))
	assert(WebFallback.is_text_payload("TEXT/HTML"))
	assert(WebFallback.is_text_payload("application/xhtml+xml"))
	assert(WebFallback.is_text_payload("text/plain"))
	assert(WebFallback.is_text_payload("application/json"))
	assert(WebFallback.is_text_payload(StringUtils.EMPTY))
	pass


func is_text_payload_rejects_binary_test() -> void:
	assert(not WebFallback.is_text_payload("application/pdf"))
	assert(not WebFallback.is_text_payload("image/png"))
	assert(not WebFallback.is_text_payload("application/octet-stream"))
	assert(not WebFallback.is_text_payload("application/zip"))
	pass


func has_body_test() -> void:
	assert(WebFallback.has_body(usable_response(200, "hello")))
	# A server that answers with `Connection: close` leaves success false although the body arrived.
	assert(WebFallback.has_body(closed_response(200, "hello")))
	assert(not WebFallback.has_body(closed_response(404, "not found")))
	assert(not WebFallback.has_body(closed_response(200, StringUtils.EMPTY)))
	pass


func read_text_test() -> void:
	var response := usable_response(200, "hello")
	assert(WebFallback.read_text(response) == "hello")
	pass


func read_text_caps_body_test() -> void:
	var oversized := PackedByteArray()
	oversized.resize(WebFallback.MAX_BODY_BYTES + 16)
	oversized.fill("a".to_utf8_buffer()[0])
	var response := usable_response(200, StringUtils.EMPTY)
	response.body = oversized
	assert(WebFallback.read_text(response).length() == WebFallback.MAX_BODY_BYTES)
	pass


static func usable_response(code: int, body: String) -> HttpResponse:
	var response := HttpResponse.new()
	response.success = true
	response.code = code
	response.body = body.to_utf8_buffer()
	return response


static func closed_response(code: int, body: String) -> HttpResponse:
	var response := usable_response(code, body)
	response.success = false
	response.error = "Http connection error:[STATUS_CONNECTION_ERROR]"
	return response
