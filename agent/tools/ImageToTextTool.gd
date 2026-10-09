class_name ImageToTextTool
extends AgentTool

const NAME := "image_to_text"
const ARG_PATH := "path"
const ARG_PROMPT := "prompt"

const MAX_PROMPT_LENGTH := 4000


func _init() -> void:
	name = NAME
	description = "Describe an image or extract its visible text with the local MiniCPM-V vision model. Requires an image path and an instruction prompt."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Absolute or project-relative image path", true)
	params.string_prop(ARG_PROMPT, "Image instruction, such as OCR, description, or structured extraction", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path := AgentWorkspace.resolve_path(str(args.get(ARG_PATH, "")))
	if StringUtils.is_blank(path):
		return AgentToolResult.error("error: path is required")
	if not FileAccess.file_exists(path):
		return AgentToolResult.error(StringUtils.format("error: image not found: {}", path))
	if StringUtils.is_blank(ImageHelper.get_image_format(path, StringUtils.EMPTY)):
		return AgentToolResult.error(StringUtils.format("error: unsupported image format: {}", path))

	var prompt := StringUtils.truncate(str(args.get(ARG_PROMPT, "")).strip_edges(), MAX_PROMPT_LENGTH)
	var output := await VLMServer.async_image_to_text(path, prompt)
	if StringUtils.is_blank(output):
		return AgentToolResult.error("error: image-to-text returned no text", AgentToolResult.ui_file_details_message(path, "no text returned"))

	var text := StringUtils.truncate(output, MAX_OUTPUT, TRUNCATED_SUFFIX)
	return AgentToolResult.ok(text)
# AgentTool-Interface-Implement-End
