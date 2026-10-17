class_name WebServer
extends Object

## Manages the local TypeScript web server and wraps all of its HTTP endpoints.

const START_TIMEOUT_MILLIS: int = 2 * TimeUtils.MILLIS_PER_MINUTE
const PROCESS_ID_STOPPED: int = -1
const PROCESS_ID_STARTING: int = -2
const NPM_CLI_PATH := ".dependency/node/node_modules/npm/bin/npm-cli.js"
const WEB_ENV_PATH := "web/.env"

static var process_id: int = PROCESS_ID_STOPPED
static var server_host: String = "127.0.0.1"
static var server_port: int = 33713
static var request_timeout_millis: int = 45 * TimeUtils.MILLIS_PER_SECOND
static var browser_headless: bool = false


class HealthyResponse extends RefCounted:
	var status: String
	var browser: String
	var uptimeSeconds: int
	pass


class FetchResponse extends RefCounted:
	var url: String
	var finalUrl: String
	var title: String
	var description: String
	var author: String
	var published: String
	var site: String
	var domain: String
	var language: String
	var favicon: String
	var image: String
	var content: String
	var contentType: String
	var wordCount: int
	pass


class SearchResult extends RefCounted:
	var position: int
	var title: String
	var url: String
	var snippet: String
	pass


class SearchResponse extends RefCounted:
	var query: String
	var results: Array[SearchResult] = []
	pass


class StopResponse extends RefCounted:
	var status: String
	pass


## Stops the owned server when the application exits.
static func _static_init() -> void:
	load_server_config()
	await ThreadUtils.async_sleep(TimeUtils.MILLIS_PER_SECOND)
	gdf.events.application_end.connect(stop_process)
	AgentEvents.events.proxy_address_changed.connect(on_proxy_address_changed)
	pass


## Starts npm from the bundled Node.js dependency and waits until CloakBrowser is ready.
## Concurrent callers share the same startup instead of spawning duplicate processes.
static func async_ensure_server_running() -> int:
	if await async_health():
		return OK
	while process_id == PROCESS_ID_STARTING:
		await ThreadUtils.async_sleep(250)
		if await async_health():
			return OK
	process_id = PROCESS_ID_STARTING
	var node := FileUtils.globalize_writable_path(DependencyManifest.get_runtime_bin("node"))
	var npm_cli := FileUtils.globalize_writable_path(NPM_CLI_PATH)
	var web_path := FileUtils.globalize_writable_path(WEB_ENV_PATH.get_base_dir())
	if not FileAccess.file_exists(node):
		Log.error("web server node dependency is missing:[{}]", node)
		process_id = PROCESS_ID_STOPPED
		return ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(npm_cli):
		Log.error("web server npm CLI dependency is missing:[{}]", npm_cli)
		process_id = PROCESS_ID_STOPPED
		return ERR_FILE_NOT_FOUND
	if not DirAccess.dir_exists_absolute(web_path):
		Log.error("web server project is missing:[{}]", web_path)
		process_id = PROCESS_ID_STOPPED
		return ERR_FILE_NOT_FOUND

	var args := PackedStringArray([npm_cli, "--prefix", web_path, "start"])
	args.append("--")
	args.append("--browser-headless={}".format([str(browser_headless).to_lower()], "{}"))
	var proxy_address := ApiSetting.get_proxy_address()
	if StringUtils.is_not_blank(proxy_address):
		args.append("--proxy-address={}".format([proxy_address], "{}"))
	process_id = OS.create_process(node, args, false)
	if process_id <= 0:
		Log.error("failed to start web server node:[{}]", node)
		process_id = PROCESS_ID_STOPPED
		return ERR_CANT_FORK

	var deadline := Time.get_ticks_msec() + START_TIMEOUT_MILLIS
	while Time.get_ticks_msec() < deadline:
		if not OS.is_process_running(process_id):
			Log.error("web server exited during startup")
			process_id = PROCESS_ID_STOPPED
			return FAILED
		if await async_health():
			Log.info("web server started pid:[{}] url:[{}]", process_id, server_url())
			return OK
		await ThreadUtils.async_sleep(500)
	Log.error("web server startup timed out")
	stop_process()
	return ERR_TIMEOUT


static func on_proxy_address_changed(_proxy_address: String) -> void:
	if not await async_health():
		return
	await async_stop()
	var deadline := Time.get_ticks_msec() + request_timeout_millis
	while Time.get_ticks_msec() < deadline:
		if not await async_health():
			var error := await async_ensure_server_running()
			if error != OK:
				Log.error("web server restart failed after proxy address changed error:[{}]", error)
			return
		await ThreadUtils.async_sleep(100)
	Log.error("web server shutdown timed out before restart")
	pass


## Immediately stops the owned child process. Prefer async_stop() when awaiting is possible.
static func stop_process() -> void:
	var pid := process_id
	process_id = PROCESS_ID_STOPPED
	if pid > 0:
		OSUtils.kill_process(pid, 0)
		Log.info("web server stopped pid:[{}]", pid)
	pass


static func is_running() -> bool:
	return process_id > 0 and OS.is_process_running(process_id)


static func server_url() -> String:
	return "http://{}:{}".format([server_host, server_port], "{}")


## Reads HOST and PORT using the same .env file consumed by the Node.js server.
static func load_server_config() -> void:
	var absolute_path := FileUtils.globalize_writable_path(WEB_ENV_PATH)
	if not FileAccess.file_exists(absolute_path):
		Log.error("web server environment file is missing:[{}]", absolute_path)
		return
	for raw_line in FileUtils.read_file_to_lines(absolute_path, true):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var separator := line.find("=")
		if separator <= 0:
			continue
		var key := line.substr(0, separator).strip_edges()
		var value := line.substr(separator + 1).strip_edges()
		if value.length() >= 2 and ((value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'"))):
			value = value.substr(1, value.length() - 2)
		if key == "HOST":
			server_host = value
		elif key == "PORT":
			server_port = int(value)
		elif key == "REQUEST_TIMEOUT_MS" and int(value) > 0:
			request_timeout_millis = int(value)
		elif key == "BROWSER_HEADLESS":
			var normalized_value := value.to_lower()
			if normalized_value == "true" or normalized_value == "false":
				browser_headless = normalized_value == "true"
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Web server APIs
# ----------------------------------------------------------------------------------------------------------------------
static func async_health() -> bool:
	var response := await HttpHelper.async_get(server_url() + "/healthy", TimeUtils.MILLIS_PER_SECOND)
	if response.code != HTTPClient.RESPONSE_OK:
		return false
	var result: HealthyResponse = JsonUtils.json_to_object(response.get_body_string(), HealthyResponse)
	return result != null and result.status == "ok"


## POST /fetch. Returns the page metadata and its extracted Markdown content.
static func async_fetch(url: String) -> FetchResponse:
	if StringUtils.is_blank(url):
		Log.error("web fetch url is empty")
		return null
	if await async_ensure_server_running() != OK:
		return null
	var payload := {"url": url}
	var response := await HttpHelper.async_post(server_url() + "/fetch", JsonUtils.object_to_json(payload), PackedStringArray(), request_timeout_millis)
	if not response.success:
		Log.error("web server request failed path:[/fetch] code:[{}] error:[{}]", response.code, response.get_error_string())
		return null
	var result: FetchResponse = JsonUtils.json_to_object(response.get_body_string(), FetchResponse)
	if result == null:
		Log.error("web server returned invalid JSON path:[/fetch]")
	return result


## POST /search. Returns up to count Bing results.
static func async_search(query: String, count: int = 10) -> SearchResponse:
	if StringUtils.is_blank(query):
		Log.error("web search query is empty")
		return null
	if count < 1 or count > 100:
		Log.error("web search count must be between 1 and 100 count:[{}]", count)
		return null
	if await async_ensure_server_running() != OK:
		return null
	var payload := {"query": query, "count": count}
	var response := await HttpHelper.async_post(server_url() + "/search", JsonUtils.object_to_json(payload), PackedStringArray(), request_timeout_millis)
	if not response.success:
		Log.error("web server request failed path:[/search] code:[{}] error:[{}]", response.code, response.get_error_string())
		return null
	var result: SearchResponse = JsonUtils.json_to_object(response.get_body_string(), SearchResponse)
	if result == null:
		Log.error("web server returned invalid JSON path:[/search]")
	return result


## POST /stop. Requests a graceful shutdown and releases the recorded process ID.
static func async_stop() -> StopResponse:
	if not await async_health():
		stop_process()
		return null
	var response := await HttpHelper.async_post(server_url() + "/stop", JsonUtils.object_to_json({}), PackedStringArray(), request_timeout_millis)
	var result: StopResponse = JsonUtils.json_to_object(response.get_body_string(), StopResponse) if response.success else null
	# Node schedules SIGTERM immediately after sending the body. On Windows the process can close the
	# socket before the client receives it, so a confirmed shutdown is equivalent to the documented reply.
	if result == null and not await async_health():
		result = StopResponse.new()
		result.status = "stopping"
	if result == null:
		Log.error("web server stop failed code:[{}] error:[{}]", response.code, response.get_error_string())
	stop_process()
	return result
