class_name ReadImageRemoteTool
extends ReadImageTool


func _init() -> void:
	name = NAME
	description = "Read a PNG/JPEG/WebP/GIF file and return the image itself. Large images are downscaled automatically; do not install image libraries or create thumbnails to inspect an image."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.object().string_prop(ARG_PATH, "Path to the image file, resolved by the filesystem backend.", true)


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path_result := resolve_image_path(str(args.get(ARG_PATH, "")))
	if path_result.is_error:
		return path_result
	var path := path_result.content

	var image_message := ChatMessage.user_image(StringUtils.EMPTY, path)
	if StringUtils.is_blank(image_message.image_data_url):
		return AgentToolResult.error("error: image could not be encoded for the API", AgentToolResult.ui_file_details_message(path, "image encoding failed"))
	var result := AgentToolResult.ok(StringUtils.format("Image read successfully: {}", path), AgentToolResult.ui_file_details(-1, -1, path))
	result.deferred_messages.append(image_message)
	return result
# AgentTool-Interface-Implement-End
