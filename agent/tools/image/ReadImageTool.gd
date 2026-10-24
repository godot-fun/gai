@abstract
class_name ReadImageTool
extends AgentTool

const NAME := "read_image"
const ARG_PATH := "path"


func resolve_image_path(raw_path: String) -> AgentToolResult:
	if StringUtils.is_blank(raw_path):
		return AgentToolResult.error("error: path is required", AgentToolResult.ui_file_details_message("", "path is required"))
	var path := AgentWorkspace.resolve_path(raw_path)
	if not SandboxPolicy.check_path_access(path):
		return AgentToolResult.error(StringUtils.format("error: sandbox denied path outside workspace: {}", path), AgentToolResult.ui_file_details_message(path, "path outside workspace"))
	if not FileAccess.file_exists(path):
		return AgentToolResult.error(StringUtils.format("error: image not found: {}", path), AgentToolResult.ui_file_details_message(path, "image not found"))
	if StringUtils.is_blank(ImageHelper.get_image_format(path, StringUtils.EMPTY)):
		return AgentToolResult.error(StringUtils.format("error: unsupported image format: {}", path), AgentToolResult.ui_file_details_message(path, "unsupported image format"))
	return AgentToolResult.ok(path, AgentToolResult.ui_file_details(-1, -1, path))
