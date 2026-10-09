class_name AsyncHttp
extends IComponent

const DEFAULT_TIMEOUT_MILLIS: int = 60 * TimeUtils.MILLIS_PER_SECOND

# SignalBridge
var signalTasks: Array[HttpTask] = []

func _init() -> void:
	start()
	pass

# IComponent-Interface-Implement-Start
func start() -> void:
	super.start()
	pass

func update() -> void:
	if signalTasks.is_empty():
		return
	var finishedTasks: Array[HttpTask] = []
	for task in signalTasks:
		if !task.done:
			_poll_task(task)
		if task.done:
			finishedTasks.append(task)
	if finishedTasks.is_empty():
		return
	for task in finishedTasks:
		# task.emit_signal("http_signal", task.response)
		task.http_signal.emit(task.response)
	finishedTasks.clear()
	pass
# IComponent-Interface-Implement-End

func _poll_task(task: HttpTask) -> void:
	var client := task.client
	client.poll()
	
	var now := TimeUtils.current_time_millis()
	if (now - task.startTime) > task.timeout_millis:
		fail(task)
		Log.error("HTTP Request timeout url:[{}] timeout:[{}]", task.url, task.timeout_millis)
		return
	
	var status := client.get_status()
	var response := task.response
	match status:
		HTTPClient.STATUS_CANT_RESOLVE:
			fail(task)
			Log.error("Http resolve error:[STATUS_CANT_RESOLVE] url:[{}]", task.url)
		HTTPClient.STATUS_CANT_CONNECT:
			fail(task)
			Log.error("Http connect error:[STATUS_CANT_CONNECT] url:[{}]", task.url)
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			fail(task)
			Log.error("Http tls error:[STATUS_TLS_HANDSHAKE_ERROR] url:[{}]", task.url)
		HTTPClient.STATUS_CONNECTION_ERROR:
			fail(task)
			Log.error("Http connection error:[STATUS_CONNECTION_ERROR] url:[{}]", task.url)
		HTTPClient.STATUS_DISCONNECTED:
			# Connection: close — body finished (or failed before request)
			if task.has_requested:
				complete(task)
			else:
				fail(task)
				Log.error("Http connection error:[STATUS_DISCONNECTED] url:[{}]", task.url)
		HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			pass
		HTTPClient.STATUS_CONNECTED:
			if task.has_requested:
				# Keep-alive — finished receiving body
				complete(task)
				return
			var err := client.request(task.method, HttpUtils.get_path_from_url(task.url), task.headers, task.body)
			if err != OK:
				fail(task)
				Log.error("Http request error url:[{}]", task.url)
			else:
				task.has_requested = true
		HTTPClient.STATUS_BODY:
			if !client.has_response():
				return
				
			var chunk := client.read_response_body_chunk()
			# prefer using the length.
			if client.get_response_body_length() > 0:
				if task.on_body_chunk.is_valid():
					task.on_body_chunk.call(chunk)
				response.body.append_array(chunk)
				if response.body.size() >= client.get_response_body_length():
					complete(task)
				return

			if chunk.size() > 0:
				if task.on_body_chunk.is_valid():
					task.on_body_chunk.call(chunk)
				response.body.append_array(chunk)
					
		pass

func fail(task: HttpTask) -> void:
	if task.done:
		return
	var client := task.client
	task.done = true
	client.close()
	pass

func complete(task: HttpTask) -> void:
	if task.done:
		return
	var client := task.client
	var response := task.response
	# read complete
	response.code = client.get_response_code()
	response.headers = client.get_response_headers_as_dictionary()
	response.success = true
	task.done = true
	client.close()
	Log.info("HTTP request successful url:[{}] code:[{}] body length:[{}]", task.url, response.code, response.body.size())
	pass


## Stops the most recently started request that is still running.
func stop_last() -> void:
	for index in range(signalTasks.size() - 1, -1, -1):
		var task := signalTasks[index]
		if !task.done:
			fail(task)
			return
	pass

## Stops all requests that are still running.
func stop_all() -> void:
	for task in signalTasks:
		fail(task)
	pass


####################################################################################################
## timeout_millis: request timeout in milliseconds (default 60s)
## proxy: optional proxy address, e.g. "127.0.0.1:10809" or "http://127.0.0.1:10809"
## cancel_scope: optional cancellation scope; cancelling it fails only this task (see CancelScope).
func async_request(method: HTTPClient.Method, url: String, body: String = "", headers: PackedStringArray = PackedStringArray(), timeout_millis: int = DEFAULT_TIMEOUT_MILLIS, proxy: String = "", on_body_chunk: Callable = Callable(), cancel_scope: CancelScope = null) -> HttpResponse:
	if !HttpUtils.is_valid_http_url(url):
		Log.error("Http is not valid http url:[{}]", url)
		return HttpResponse.new()
	var host := HttpUtils.get_host_from_url(url)
	var port := HttpUtils.get_port_from_url(url)
	Log.info("Http request url:[{}]", url)
	var client := HTTPClient.new()
	if StringUtils.is_not_blank(proxy):
		var proxy_host := HttpUtils.get_host_from_url(proxy)
		var proxy_port := HttpUtils.get_port_from_url(proxy)
		client.set_http_proxy(proxy_host, proxy_port)
		client.set_https_proxy(proxy_host, proxy_port)
		Log.info("Http proxy:[{}], host:[{}], port:[{}]", proxy, proxy_host, proxy_port)
	var err := client.connect_to_host(host, port, TLSOptions.client()) if HttpUtils.is_https_url(url) else client.connect_to_host(host, port)
	if err != OK:
		Log.error("Http connect error:[{}]", err)
		return HttpResponse.new()

	var signalId := IdUtils.local_id()
	var task: HttpTask = HttpTask.new(signalId, client, method, url, headers, body, timeout_millis)
	task.on_body_chunk = on_body_chunk
	signalTasks.append(task)
	if cancel_scope != null:
		cancel_scope.track(func() -> void: fail(task))
	var response: HttpResponse = await task.http_signal
	var index := signalTasks.find(task)
	signalTasks.remove_at(index)
	return response


####################################################################################################
class HttpTask:
	signal http_signal(response: HttpResponse)

	var signalId: int
	var client: HTTPClient
	var method: HTTPClient.Method
	var url: String
	var headers: PackedStringArray
	var body: String
	var timeout_millis: int
	var startTime: int
	var response: HttpResponse = HttpResponse.new()
	var done: bool = false
	var has_requested: bool = false
	var on_body_chunk: Callable = Callable()

	func _init(_signalId: int, _client: HTTPClient, _method: HTTPClient.Method, _url: String, _headers: PackedStringArray, _body: String, _timeout_millis: int = AsyncHttp.DEFAULT_TIMEOUT_MILLIS):
		self.signalId = _signalId
		self.client = _client
		self.method = _method
		self.url = _url
		self.headers = _headers
		self.body = _body
		self.timeout_millis = _timeout_millis
		self.startTime = TimeUtils.current_time_millis()
		pass
