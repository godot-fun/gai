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


static func completion_is_error_when_request_failed_test() -> void:
	# The invariant behind fail-fast: a failed request can never look like an empty answer.
	var response := HttpResponse.failure("Http request cancelled url:[x]")
	var completion := OpenAiCompletion.new()
	completion.error = StringUtils.format("request failed, http code:[{}], {}", response.code, response.get_error_string())
	assert(completion.has_error())
	pass
