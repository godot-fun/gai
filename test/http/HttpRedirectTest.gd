static func redirect_code_test() -> void:
	var response := HttpResponse.new()
	response.code = HTTPClient.RESPONSE_MOVED_PERMANENTLY
	assert(response.is_redirect())
	response.code = HTTPClient.RESPONSE_PERMANENT_REDIRECT
	assert(response.is_redirect())
	response.code = HTTPClient.RESPONSE_OK
	assert(not response.is_redirect())
	pass


static func response_header_is_case_insensitive_test() -> void:
	var response := HttpResponse.new()
	response.headers = {"location": " https://cdn.example.com/a.png "}
	assert(response.get_header("Location") == "https://cdn.example.com/a.png")
	pass


static func absolute_redirect_url_test() -> void:
	assert(HttpUtils.resolve_url("https://example.com/a.png", "https://cdn.example.com/b.png") == "https://cdn.example.com/b.png")
	pass


static func protocol_relative_redirect_url_test() -> void:
	assert(HttpUtils.resolve_url("https://example.com/a.png", "//cdn.example.com/b.png") == "https://cdn.example.com/b.png")
	pass


static func root_relative_redirect_url_test() -> void:
	assert(HttpUtils.resolve_url("https://example.com/old/a.png", "/new/b.png") == "https://example.com/new/b.png")
	pass


static func path_relative_redirect_url_test() -> void:
	assert(HttpUtils.resolve_url("https://example.com/old/a.png?size=2", "b.png") == "https://example.com/old/b.png")
	pass
