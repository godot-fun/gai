class_name HttpHelper
extends Object

static var http: AsyncHttp = AsyncHttp.new()


## timeout_millis: request timeout in milliseconds (default 60s)
## proxy: optional proxy address, e.g. "127.0.0.1:10809"
## cancel_scope: optional cancellation scope; cancelling it aborts only this request (see CancelScope).
static func async_get(url: String, timeout_millis: int = AsyncHttp.DEFAULT_TIMEOUT_MILLIS, proxy: String = "", extra_headers: PackedStringArray = PackedStringArray(), cancel_scope: CancelScope = null) -> HttpResponse:
	var request_url := url
	var response: HttpResponse
	for _request_count in 18:
		response = await http.async_request(HTTPClient.METHOD_GET, request_url, "", extra_headers, timeout_millis, proxy, Callable(), cancel_scope)
		if not response.success or not response.is_redirect():
			return response
		var location := response.get_header("Location")
		var redirect_url := HttpUtils.resolve_url(request_url, location)
		if not HttpUtils.is_valid_http_url(redirect_url):
			return response
		request_url = redirect_url
	response.success = false
	response.error = StringUtils.format("Http redirect limit reached url:[{}]", url)
	return response


static func async_post(url: String, json: String, extra_headers: PackedStringArray = PackedStringArray(), timeout_millis: int = AsyncHttp.DEFAULT_TIMEOUT_MILLIS, proxy: String = "", on_body_chunk: Callable = Callable(), cancel_scope: CancelScope = null) -> HttpResponse:
	var headers := extra_headers.duplicate()
	if not HttpUtils.has_header(headers, "Content-Type"):
		headers.insert(0, "Content-Type: application/json")
	return await http.async_request(HTTPClient.METHOD_POST, url, json, headers, timeout_millis, proxy, on_body_chunk, cancel_scope)


## Stops the most recently started HTTP request that is still running.
static func stop_last() -> void:
	http.stop_last()
	pass


## Stops all HTTP requests that are still running.
static func stop_all() -> void:
	http.stop_all()
	pass
