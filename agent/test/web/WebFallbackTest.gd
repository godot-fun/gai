## Offline tests for the plain-HTTP fallback helpers: payload type filtering. No network, no browser.
## The extraction itself (decoding + article picking) is covered by HtmlHelperTest.

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


