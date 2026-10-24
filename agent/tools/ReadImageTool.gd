class_name ReadImageTool
extends AgentTool

const NAME := "read_image"
const ARG_PATH := "path"

const REMOTE_ATTACH_TEXT := "Image attached for model inspection."


func _init() -> void:
	name = NAME
	description = "Read a PNG/JPEG/WebP/GIF file and return the image itself. Large images are downscaled automatically; do not install image libraries or create thumbnails to inspect an image."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_PATH, "Path to the image file, resolved by the filesystem backend.", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var raw_path := str(args.get(ARG_PATH, ""))
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required")
	var path := AgentWorkspace.resolve_path(raw_path)
	if not SandboxPolicy.check_path_access(path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", path))
	if not FileAccess.file_exists(path):
		return AgentToolResult.error(StringUtils.format("error: image not found: {}", path))
	if StringUtils.is_blank(ImageHelper.get_image_format(path, StringUtils.EMPTY)):
		return AgentToolResult.error(StringUtils.format("error: unsupported image format: {}", path))

	var image_message := ChatMessage.user_image(REMOTE_ATTACH_TEXT, path)
	if StringUtils.is_blank(image_message.image_data_url):
		return AgentToolResult.error("error: image could not be encoded for the API", AgentToolResult.ui_file_details_message(path, "image encoding failed"))
	var result := AgentToolResult.ok(StringUtils.format("Image loaded from {} and attached for model inspection.", path))
	result.deferred_messages.append(image_message)
	return result
# AgentTool-Interface-Implement-End
