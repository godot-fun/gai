class_name AudioToTextTool
extends AgentTool

const NAME := "audio_to_text"
const ARG_PATH := "path"

const SCRIPT_REL_PATH := ".ai/audio-to-text/transcribe.py"
const TIMEOUT_MILLIS := TimeUtils.MILLIS_PER_MINUTE * 10


func _init() -> void:
	name = NAME
	description = "Transcribe speech from a PCM16 WAV audio file to plain text with the local SenseVoice model. Requires an uncompressed PCM16 WAV path."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Absolute or project-relative path to a PCM16 WAV audio file", true)
	return params


func async_execute(args: Dictionary[String, Variant]) -> AgentToolResult:
	var raw_path := str(args.get(ARG_PATH, "")).strip_edges()
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required")
	var path := AgentWorkspace.resolve_path(raw_path)
	if not FileAccess.file_exists(path):
		return AgentToolResult.error(StringUtils.format("error: audio not found: {}", path))
	if not path.to_lower().ends_with(".wav"):
		return AgentToolResult.error(StringUtils.format("error: SenseVoice requires PCM16 WAV input: {}", path))
	if not DependencyManifest.has_populated_runtime(DependencyManifest.PYTHON_PATH):
		return AgentToolResult.error(DependencyManifest.PYTHON_INSTALL_PROMPT)

	var argv := PackedStringArray([DependencyManifest.PYTHON_PATH, SCRIPT_REL_PATH, "--audio", path])
	var exec_result := await OSUtils.async_execute(argv, false, TIMEOUT_MILLIS)
	var output := exec_result.output.build_string().strip_edges()
	if exec_result.exit_code != 0:
		var message := output if StringUtils.is_not_blank(output) else StringUtils.format("error: audio-to-text failed (exit {})", exec_result.exit_code)
		return AgentToolResult.error(message, AgentToolResult.ui_file_details_message(path, "transcription failed"))
	if StringUtils.is_blank(output):
		return AgentToolResult.error("error: audio-to-text returned no text", AgentToolResult.ui_file_details_message(path, "no text returned"))

	var text := StringUtils.truncate(output, MAX_OUTPUT, TRUNCATED_SUFFIX)
	return AgentToolResult.ok(text)
# AgentTool-Interface-Implement-End
