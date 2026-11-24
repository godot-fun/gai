class_name LlamServer
extends Object

## Manages the built-in llama.cpp HTTP service used for local model capabilities.

const SERVER_HOST: String = "127.0.0.1"
const IDLE_TIMEOUT_SECONDS: int = 5 * 60
const IDLE_TIMEOUT_MILLIS: int = IDLE_TIMEOUT_SECONDS * TimeUtils.MILLIS_PER_SECOND
const START_TIMEOUT_MILLIS: int = 2 * TimeUtils.MILLIS_PER_MINUTE
const MIN_GPU_FREE_MEMORY_MIB: int = 22 * 1024
## Qwen3.8 supports 256K natively, but a 24GB desktop GPU needs a smaller resident context.
const CONTEXT_SIZE: int = 32768
const MODEL_NAME: String = "Qwen3.8-27B-Q4_K_M.gguf"
const PROCESS_ID_STOPPED: int = -1
const PROCESS_ID_STARTING: int = -2

## Local dependency paths are resolved from the project root for a consistent runtime layout.
const MODEL_PATH := ".dependency/qwen3.8-27b/model/Qwen3.8-27B-Q4_K_M.gguf"
const MMPROJ_PATH := ".dependency/qwen3.8-27b/model/mmproj-Qwen3.8-27B-BF16.gguf"
const GPU_SERVER_PATH := ".dependency/llama-cpp-gpu/llama-server.exe"
const CPU_SERVER_PATH := ".dependency/llama-cpp-cpu/llama-server.exe"

static var process_id: int = PROCESS_ID_STOPPED
static var server_port: int = 31713
static var last_access_millis: int = 0


## Registers the idle monitor once per script class. Registration is deferred because static
## initialization can run before the GodotFramework autoload has entered `_ready()`.
static func _static_init() -> void:
	await ThreadUtils.async_sleep(TimeUtils.MILLIS_PER_SECOND)
	gdf.events.application_end.connect(stop)
	SchedulerBus.schedule_at_fixed_rate(check_idle_timeout, TimeUtils.MILLIS_PER_SECOND, "llam_server_idle")
	pass

## Releases the model after five minutes without a request renewing the idle lease.
static func check_idle_timeout() -> void:
	if is_running() and last_access_millis > 0 and TimeUtils.current_time_millis() - last_access_millis >= IDLE_TIMEOUT_MILLIS:
		stop()
	pass


## Text-only chat through the same OpenAI-compatible endpoint.
## Returns an empty string when startup fails or inference fails.
static func async_chat(prompt: String, system_prompt: String = "", max_tokens: int = 2048) -> String:
	var messages: Array = []
	if StringUtils.is_not_blank(system_prompt):
		messages.append({"role": "system", "content": system_prompt})
	messages.append({"role": "user", "content": prompt})
	return await async_chat_completion(messages, max_tokens)


## Sends one image and prompt to the managed OpenAI-compatible vision endpoint.
## Returns an empty string when the image cannot be read, startup fails, or inference fails.
static func async_image_to_text(image_path: String, prompt: String) -> String:
	var image_bytes := FileUtils.read_file_to_byte_array(image_path)
	if image_bytes.is_empty():
		Log.error("local model image read failed path:[{}]", image_path)
		return StringUtils.EMPTY
	var image_format := ImageHelper.detect_image_format(image_bytes)
	if image_format.is_empty():
		Log.error("local model image format is unsupported path:[{}]", image_path)
		return StringUtils.EMPTY
	var mime_subtype := "jpeg" if image_format == ImageHelper.jpg else image_format
	var image_data_url := "data:image/{};base64,{}".format([mime_subtype, Marshalls.raw_to_base64(image_bytes)], "{}")
	var messages: Array = [{
		"role": "user",
		"content": [
			{"type": "text", "text": prompt},
			{"type": "image_url", "image_url": {"url": image_data_url}},
		],
	}]
	return await async_chat_completion(messages)


## Posts a non-streaming chat completion after ensuring the local server is ready.
static func async_chat_completion(messages: Array, max_tokens: int = 2048) -> String:
	if messages.is_empty():
		Log.error("local model messages is empty")
		return StringUtils.EMPTY
	last_access_millis = TimeUtils.current_time_millis()
	var error: int = await async_ensure_server_running()
	if error != OK:
		return StringUtils.EMPTY
	var payload: Dictionary = {
		"model": MODEL_NAME,
		"messages": messages,
		"temperature": 0,
		"max_tokens": max_tokens,
		"stream": false,
	}
	var response := await HttpHelper.async_post(server_url() + "/v1/chat/completions", JSON.stringify(payload), PackedStringArray())
	if not response.is_ok():
		Log.error("local model request failed code:[{}] body:[{}]", response.code, response.get_body_string())
		return StringUtils.EMPTY
	var data: Variant = response.get_body_json()
	if typeof(data) != TYPE_DICTIONARY:
		Log.error("local model returned invalid JSON")
		return StringUtils.EMPTY
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		Log.error("local model response has no choices body:[{}]", response.get_body_string())
		return StringUtils.EMPTY
	var content := str(choices[0].get("message", {}).get("content", "")).strip_edges()
	if content.is_empty():
		Log.error("local model response has no content body:[{}]", response.get_body_string())
	Log.info("------------------------------------------------------------------------------------------------------")
	Log.info(content)
	Log.info("------------------------------------------------------------------------------------------------------")
	return content


## Explicit service-control entry point used by settings and other user-initiated actions.
static func async_start() -> int:
	return await async_ensure_server_running()


## Ensures one service is running and waits for its HTTP endpoint. Concurrent callers share the
## same cold start through the PROCESS_ID_STARTING sentinel instead of spawning duplicate processes.
static func async_ensure_server_running() -> int:
	last_access_millis = TimeUtils.current_time_millis()
	if is_running() and await LlamaHelper.async_health(server_url()):
		return OK
	while process_id == PROCESS_ID_STARTING:
		await ThreadUtils.async_sleep(TimeUtils.MILLIS_PER_SECOND)
		if is_running():
			return OK
	process_id = PROCESS_ID_STARTING
	var available_port := NetUtils.find_available_port(server_port)
	if available_port < 0:
		Log.error("no available port found for local model service")
		process_id = PROCESS_ID_STOPPED
		return ERR_CANT_CREATE
	server_port = available_port

	var executable := select_server_executable()
	var model := FileUtils.globalize_writable_path(MODEL_PATH)
	var mmproj := FileUtils.globalize_writable_path(MMPROJ_PATH)
	for required in [executable, model, mmproj]:
		if not FileAccess.file_exists(required):
			Log.error("local model service dependency is missing:[{}]", required)
			process_id = PROCESS_ID_STOPPED
			return ERR_FILE_NOT_FOUND

	var args := build_server_args(model, mmproj, executable.contains("llama-cpp-gpu"))
	process_id = OS.create_process(executable, args, false)
	if process_id <= 0:
		Log.error("failed to start local model service:[{}]", executable)
		process_id = PROCESS_ID_STOPPED
		return ERR_CANT_FORK

	var deadline := TimeUtils.current_time_millis() + START_TIMEOUT_MILLIS
	while TimeUtils.current_time_millis() < deadline:
		if not OS.is_process_running(process_id):
			Log.error("local model service exited during startup")
			process_id = PROCESS_ID_STOPPED
			return FAILED
		if await LlamaHelper.async_health(server_url()):
			Log.info("local model service started pid:[{}] url:[{}]", process_id, server_url())
			return OK
		await ThreadUtils.async_sleep(500)
	Log.error("local model service startup timed out")
	stop()
	return ERR_TIMEOUT


## Stops the owned child process, releasing model memory, KV cache, and GPU allocations. mmap-backed
## model pages may remain in the operating-system file cache to accelerate the next cold start.
static func stop() -> void:
	var pid := process_id
	process_id = PROCESS_ID_STOPPED
	if pid > 0:
		OSUtils.kill_process(pid, 0)
		Log.info("local model service stopped pid:[{}]", pid)
	pass


## Returns whether the recorded llama-server child process still exists.
static func is_running() -> bool:
	return process_id > 0 and OS.is_process_running(process_id)


## Returns the actual endpoint selected at runtime, including a dynamically advanced port.
static func server_url() -> String:
	return "http://{}:{}".format([SERVER_HOST, server_port], "{}")


## Builds the llama-server command. mmap enables OS file-cache reuse, while CPU mode also keeps the
## multimodal projector off the GPU.
static func build_server_args(model: String, mmproj: String, use_gpu: bool) -> PackedStringArray:
	var args := PackedStringArray([
		"--model", model,
		"--mmproj", mmproj,
		"--load-mode", "mmap",
		"--ctx-size", str(CONTEXT_SIZE),
		"--parallel", "1",
		"--image-min-tokens", "1024",
		# Sense compose / OCR need short answers; thinking burns the token budget with empty content.
		"--reasoning", "off",
		"--no-reasoning-preserve",
		"--sleep-idle-seconds", str(IDLE_TIMEOUT_SECONDS),
		"--host", SERVER_HOST,
		"--port", str(server_port),
	])
	args.append_array(PackedStringArray(["--gpu-layers", "all"]) if use_gpu else PackedStringArray(["--gpu-layers", "0", "--no-mmproj-offload"]))
	return args


## Uses Vulkan only when discovery succeeds and a device has enough currently free VRAM; otherwise
## the CPU build is selected.
static func select_server_executable() -> String:
	var gpu_server := FileUtils.globalize_writable_path(GPU_SERVER_PATH)
	if FileAccess.file_exists(gpu_server) and gpu_has_enough_memory(gpu_server):
		return gpu_server
	return FileUtils.globalize_writable_path(CPU_SERVER_PATH)


## Queries llama.cpp device information through the shared process execution utility.
static func gpu_has_enough_memory(executable: String) -> bool:
	var result := OSUtils.execute(PackedStringArray([executable, "--list-devices"]), false)
	if result.exit_code != 0:
		return false
	var regex := RegEx.new()
	if regex.compile(r"\((\d+) MiB,\s*(\d+) MiB free\)") != OK:
		return false
	for regex_result in regex.search_all(result.output.build_string()):
		if int(regex_result.get_string(2)) >= MIN_GPU_FREE_MEMORY_MIB:
			return true
	return false
