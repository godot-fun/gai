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


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var raw_path := str(args.get(ARG_PATH, "")).strip_edges()
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required")
	var path := AgentWorkspace.resolve_path(raw_path)
	var result := await async_audio_to_text(path)
	if result.is_error:
		return AgentToolResult.error(result.content, AgentToolResult.ui_file_details_message(path, "transcription failed"))
	return AgentToolResult.ok(StringUtils.truncate(result.content, MAX_OUTPUT, TRUNCATED_SUFFIX))
# AgentTool-Interface-Implement-End


## Transcribes a PCM16 WAV file via the local SenseVoice skill script.
## [param audio_path] should be an absolute or project-relative filesystem path.
static func async_audio_to_text(audio_path: String) -> AgentToolResult:
	if StringUtils.is_blank(audio_path):
		return AgentToolResult.error("error: path is required")
	if not FileAccess.file_exists(audio_path):
		return AgentToolResult.error(StringUtils.format("error: audio not found: {}", audio_path))
	if not audio_path.to_lower().ends_with(".wav"):
		return AgentToolResult.error(StringUtils.format("error: SenseVoice requires PCM16 WAV input: {}", audio_path))
	if not DependencyManifest.has_populated_runtime(DependencyManifest.PYTHON_PATH):
		return AgentToolResult.error(DependencyManifest.PYTHON_INSTALL_PROMPT)

	var argv := PackedStringArray([DependencyManifest.PYTHON_PATH, SCRIPT_REL_PATH, "--audio", audio_path])
	var exec_result := await OSUtils.async_execute(argv, false, TIMEOUT_MILLIS)
	var output := exec_result.output.build_string().strip_edges()
	if exec_result.exit_code != 0:
		var message := output if StringUtils.is_not_blank(output) else StringUtils.format("error: audio-to-text failed (exit {})", exec_result.exit_code)
		return AgentToolResult.error(message)
	if StringUtils.is_blank(output):
		return AgentToolResult.error("error: audio-to-text returned no text")
	return AgentToolResult.ok(output)
