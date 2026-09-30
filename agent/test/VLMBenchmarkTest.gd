extends Control

## Interactive benchmark for comparing one-shot llama.cpp CLI inference with the managed HTTP server.
## Run this scene directly; both paths use the same model, image, prompt, and generation settings.

const VLM_SERVER := preload("res://agent/server/VLMServer.gd")

const IMAGE_PATH: String = "res://.ai/test/image/tank1.jpg"
const PROMPT: String = "Describe this image accurately. Include visible subjects, setting, colors, and legible text."
const REQUEST_TIMEOUT_MILLIS: int = 10 * TimeUtils.MILLIS_PER_MINUTE

@onready var cli_button: Button = $Margin/Content/CliRow/CliButton
@onready var cli_time_label: Label = $Margin/Content/CliRow/CliTime
@onready var http_button: Button = $Margin/Content/HttpRow/HttpButton
@onready var http_time_label: Label = $Margin/Content/HttpRow/HttpTime
@onready var result_text: TextEdit = $Margin/Content/Result


func _ready() -> void:
	cli_button.pressed.connect(on_cli_pressed)
	http_button.pressed.connect(on_http_pressed)
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


## Measures the complete HTTP operation, including a cold server start when the model is not resident.
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


## Formats wall-clock milliseconds for the result label beside each benchmark button.
func format_elapsed(millis: int, success: bool) -> String:
	var seconds := "%.2f" % (millis / 1000.0)
	return "{} · {} s".format(["Completed" if success else "Failed", seconds], "{}")


## Prevents overlapping runs from competing for the same model and GPU memory.
func set_running(running: bool) -> void:
	cli_button.disabled = running
	http_button.disabled = running
	pass
