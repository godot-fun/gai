class_name ReadImageTool
extends AgentTool

## Reads an image file and returns it to the model as an inline image message.

const NAME := "read_image"
const ARG_PATH := "path"


func _init() -> void:
	name = NAME
	description = "Read a PNG/JPEG/WebP/GIF file and return the image itself. Large images are downscaled automatically; do not install image libraries or create thumbnails to inspect an image."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	return ToolParameters.Parameters.new().string_prop(ARG_PATH, "Path to the image file, resolved by the filesystem backend.", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var path_result := resolve_image_path(str(args.get(ARG_PATH, "")))
	if path_result.is_error:
		return path_result
	var path := path_result.content

	# Huge images decode and re-encode for seconds; the worker pool keeps the UI responsive.
	var image_message := await UserChatMessage.async_from_image_path(StringUtils.EMPTY, path)
	if StringUtils.is_blank(image_message.first_image_data_url()):
		return AgentToolResult.error("error: image could not be encoded for the API", AgentToolResult.ui_file_details(path, "image encoding failed"))
	var result := AgentToolResult.ok(StringUtils.format("Image read successfully: {}", path), AgentToolResult.ui_file_details(path))
	result.deferred_messages.append(image_message)
	return result
# AgentTool-Interface-Implement-End


func resolve_image_path(raw_path: String) -> AgentToolResult:
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details("", "path is required"))
	var path := AgentWorkspace.resolve_path(raw_path)
	if not SandboxPolicy.check_path_access(path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", path), AgentToolResult.ui_file_details(path, "path outside workspace"))
	if not FileAccess.file_exists(path):
		return AgentToolResult.error(StringUtils.format("error: image not found: {}", path), AgentToolResult.ui_file_details(path, "image not found"))
	if StringUtils.is_blank(ImageHelper.get_image_format(path, StringUtils.EMPTY)):
		return AgentToolResult.error(StringUtils.format("error: unsupported image format: {}", path), AgentToolResult.ui_file_details(path, "unsupported image format"))
	return AgentToolResult.ok(path, AgentToolResult.ui_file_details(path))
