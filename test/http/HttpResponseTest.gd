## Unit coverage for the failed-request contract: a failed request always carries a reason, either in
## the body (the server answered with an error payload) or in [member HttpResponse.error] (the request
## never reached the server).

static func failure_carries_error_test() -> void:
	var response := HttpResponse.failure("Http is not valid http url:[x]")
	assert(not response.success)
	assert(response.code == 0)
	assert(response.get_body_string() == "")
	assert(response.error == "Http is not valid http url:[x]")
	pass


static func error_string_prefers_http_body_test() -> void:
	# A 401 from the API: the task completed, so [member HttpResponse.error] stays empty and the
	# reason only exists in the body.
	var response := HttpResponse.new()
	response.success = true
	response.code = 401
	response.body = "{\"error\":{\"message\":\"Invalid API key\"}}".to_utf8_buffer()
	assert(StringUtils.is_blank(response.error))
	assert(response.get_error_string().contains("Invalid API key"))
	pass


static func error_string_falls_back_to_transport_reason_test() -> void:
	var response := HttpResponse.failure("Http connect error:[STATUS_CANT_CONNECT] url:[http://127.0.0.1:1]")
	assert(response.get_error_string() == "Http connect error:[STATUS_CANT_CONNECT] url:[http://127.0.0.1:1]")
	pass


static func error_string_never_blank_test() -> void:
	assert(StringUtils.is_not_blank(HttpResponse.new().get_error_string()))
	pass


static func is_ok_distinguishes_completed_from_2xx_test() -> void:
	var ok := HttpResponse.new()
	ok.success = true
	ok.code = HTTPClient.RESPONSE_OK
	assert(ok.is_ok())
	var created := HttpResponse.new()
	created.success = true
	created.code = HTTPClient.RESPONSE_CREATED
	assert(created.is_ok())
	# The server answered, so the exchange completed, but not with a result.
	var not_found := HttpResponse.new()
	not_found.success = true
	not_found.code = HTTPClient.RESPONSE_NOT_FOUND
	assert(not not_found.is_ok())
	var gateway_error := HttpResponse.new()
	gateway_error.success = true
	gateway_error.code = HTTPClient.RESPONSE_BAD_GATEWAY
	assert(not gateway_error.is_ok())
	var redirect := HttpResponse.new()
	redirect.success = true
	redirect.code = HTTPClient.RESPONSE_FOUND
	assert(not redirect.is_ok())
	assert(not HttpResponse.failure("Http connect error").is_ok())
	assert(not HttpResponse.new().is_ok())
	pass


static func is_ok_with_body_keeps_a_closed_connection_payload_test() -> void:
	var response := HttpResponse.new()
	# A server that answers with `Connection: close`: the body arrives, then the peer close is
	# reported as a transport error, so [member success] stays false.
	response.success = false
	response.code = HTTPClient.RESPONSE_OK
	response.body = "hello".to_utf8_buffer()
	response.error = "Http connection error:[STATUS_CONNECTION_ERROR]"
	assert(not response.is_ok())
	assert(response.is_ok_with_body())
	pass


static func is_ok_with_body_rejects_errors_and_empty_payloads_test() -> void:
	var not_found := HttpResponse.new()
	not_found.success = true
	not_found.code = HTTPClient.RESPONSE_NOT_FOUND
	not_found.body = "<p>not found</p>".to_utf8_buffer()
	assert(not not_found.is_ok_with_body())
	var empty := HttpResponse.new()
	empty.success = true
	empty.code = HTTPClient.RESPONSE_OK
	assert(not empty.is_ok_with_body())
	assert(not HttpResponse.new().is_ok_with_body())
	pass


static func completion_is_error_when_request_failed_test() -> void:
	# The invariant behind fail-fast: a failed request can never look like an empty answer.
	var response := HttpResponse.failure("Http request cancelled url:[x]")
	var completion := OpenAiCompletion.failure(StringUtils.format("request failed, http code:[{}], {}", response.code, response.get_error_string()))
	assert(completion.has_error())
	pass
