extends Control

## Interactive benchmark for CLI vision, HTTP vision, and HTTP text-only LLM on the managed MiniCPM-V server.
## Run this scene directly; vision paths share the same model, image, prompt, and generation settings.

const VLM_SERVER := preload("res://agent/server/VLMServer.gd")

const IMAGE_PATH: String = "res://.ai/test/image/tank1.jpg"
const PROMPT: String = "Describe this image accurately. Include visible subjects, setting, colors, and legible text."
const LLM_PROMPT: String = """Write a clear, structured answer in about 200–300 words.

Topic: why local on-device vision-language models are useful for a desktop agent that must describe screenshots, draft short replies, and keep private screen content off remote APIs.

Cover these points in order:
1) privacy and offline reliability
2) latency when the model is already warm in memory
3) practical limits (hallucination, OCR errors, short context mistakes)
4) one concrete workflow example that mixes screen description with a follow-up text-only rewrite

Use plain language. End with a single-sentence takeaway."""
const LLM_SYSTEM_PROMPT: String = "You are a careful technical writer. Prefer concrete wording over slogans. Do not invent product names or benchmark numbers."
const LLM_ZH_PROMPT: String = """请用约 300 至 500 个中文字符，清晰、有条理地回答下面的问题。

主题：为什么本地端侧视觉语言模型适合桌面智能体，用于描述屏幕、起草简短回复，并避免把隐私屏幕内容发送到远程 API。

请依次说明：
1）隐私保护与离线可靠性
2）模型已常驻内存时的响应延迟
3）实际局限，包括幻觉、OCR 错误和短上下文理解错误
4）一个具体工作流示例：先描述屏幕，再进行一次纯文本改写

使用简明中文。最后用一句话总结。全文必须使用中文，不要翻译成英文；产品名、API 和技术标识可以保留原文。"""
const LLM_ZH_SYSTEM_PROMPT: String = "你是一名严谨的中文技术作者。必须使用中文回答，不得改用英文。措辞具体，不使用空泛口号，不虚构产品名称或测试数据；产品名、API 和技术标识可以保留原文。"
const REQUEST_TIMEOUT_MILLIS: int = 10 * TimeUtils.MILLIS_PER_MINUTE

@onready var cli_button: Button = $Margin/Content/CliRow/CliButton
@onready var cli_time_label: Label = $Margin/Content/CliRow/CliTime
@onready var http_button: Button = $Margin/Content/HttpRow/HttpButton
@onready var http_time_label: Label = $Margin/Content/HttpRow/HttpTime
@onready var llm_button: Button = $Margin/Content/LlmRow/LlmButton
@onready var llm_time_label: Label = $Margin/Content/LlmRow/LlmTime
@onready var llm_zh_button: Button = $Margin/Content/LlmZhRow/LlmZhButton
@onready var llm_zh_time_label: Label = $Margin/Content/LlmZhRow/LlmZhTime
@onready var result_text: TextEdit = $Margin/Content/Result


func _ready() -> void:
	cli_button.pressed.connect(on_cli_pressed)
	http_button.pressed.connect(on_http_pressed)
	llm_button.pressed.connect(on_llm_pressed)
	llm_zh_button.pressed.connect(on_llm_zh_pressed)
	pass


## Measures process creation, model loading, image inference, and process exit as one CLI operation.
## The managed server is stopped first so it cannot retain GPU memory during this comparison.
func on_cli_pressed() -> void:
	set_running(true)
	cli_time_label.text = "Running..."
	result_text.text = StringUtils.EMPTY
	VLM_SERVER.stop()
	var watch := StopWatch.new()
	var executable := VLM_SERVER.select_server_executable().replace("llama-server.exe", "llama-mtmd-cli.exe")
	var model := ProjectSettings.globalize_path(VLM_SERVER.MODEL_PATH)
	var mmproj := ProjectSettings.globalize_path(VLM_SERVER.MMPROJ_PATH)
	var image := ProjectSettings.globalize_path(IMAGE_PATH)
	var use_gpu := executable.contains("llama-cpp-gpu")
	var args := PackedStringArray([executable, "--model", model, "--mmproj", mmproj, "--image", image,
		"--prompt", PROMPT, "--ctx-size", "4096", "--predict", "1024", "--temp", "0"])
	args.append_array(PackedStringArray(["--gpu-layers", "all"]) if use_gpu else PackedStringArray([
		"--gpu-layers", "0", "--no-mmproj-offload"]))
	var response := await OSUtils.async_execute(args, false, REQUEST_TIMEOUT_MILLIS)
	cli_time_label.text = format_elapsed(watch.cost(), response.exit_code == 0)
	result_text.text = response.output.build_string().strip_edges()
	if response.exit_code != 0 and result_text.text.is_empty():
		result_text.text = "CLI request failed with exit code: {}".format([response.exit_code], "{}")
	set_running(false)
	pass


## Measures the complete HTTP vision operation, including a cold server start when the model is not resident.
## Repeated runs before the idle timeout exercise the warm resident-model path.
func on_http_pressed() -> void:
	set_running(true)
	http_time_label.text = "Running..."
	result_text.text = StringUtils.EMPTY
	var watch := StopWatch.new()
	var image_path := ProjectSettings.globalize_path(IMAGE_PATH)
	var result := await VLM_SERVER.async_image_to_text(image_path, PROMPT)
	http_time_label.text = format_elapsed(watch.cost(), not result.is_empty())
	result_text.text = result if not result.is_empty() else "Image-to-text request failed. Check the application log for details."
	set_running(false)
	pass


## Measures text-only LLM chat through the same managed OpenAI-compatible HTTP endpoint.
## Cold start cost is shared with the vision path; warm runs isolate text inference latency.
func on_llm_pressed() -> void:
	set_running(true)
	llm_time_label.text = "Running..."
	result_text.text = StringUtils.EMPTY
	var watch := StopWatch.new()
	var result := await VLM_SERVER.async_chat(LLM_PROMPT, LLM_SYSTEM_PROMPT)
	llm_time_label.text = format_elapsed(watch.cost(), not result.is_empty())
	result_text.text = result if not result.is_empty() else "LLM chat request failed. Check the application log for details."
	set_running(false)
	pass


## Measures a Chinese-only text request to expose unwanted language switching by the local model.
func on_llm_zh_pressed() -> void:
	set_running(true)
	llm_zh_time_label.text = "运行中..."
	result_text.text = StringUtils.EMPTY
	var watch := StopWatch.new()
	var result := await VLM_SERVER.async_chat(LLM_ZH_PROMPT, LLM_ZH_SYSTEM_PROMPT)
	llm_zh_time_label.text = format_elapsed(watch.cost(), not result.is_empty())
	result_text.text = result if not result.is_empty() else "中文 LLM 请求失败，请检查应用日志。"
	set_running(false)
	pass


## Formats wall-clock milliseconds for the result label beside each benchmark button.
func format_elapsed(millis: int, success: bool) -> String:
	var seconds := "%.2f" % (millis / 1000.0)
	return "{} · {} s".format(["Completed" if success else "Failed", seconds], "{}")


## Prevents overlapping runs from competing for the same model and GPU memory.
func set_running(running: bool) -> void:
	cli_button.disabled = running
	http_button.disabled = running
	llm_button.disabled = running
	llm_zh_button.disabled = running
	pass
