class_name VisualToolFormatter
extends RefCounted

## Shared tool name and glyph formatting for agent visual effects.


static func readable_name(tool_name: String) -> String:
	return tool_name.replace("_", " ").replace("-", " ").strip_edges()


static func title_name(tool_name: String, empty_default: String = "Tool") -> String:
	var readable := readable_name(tool_name)
	return readable.capitalize() if not readable.is_empty() else empty_default


static func upper_name(tool_name: String, empty_default: String = "TOOL") -> String:
	var readable := readable_name(tool_name)
	return readable.to_upper() if not readable.is_empty() else empty_default


static func gate_name(tool_name: String, max_length: int = 7, empty_default: String = "TOOL") -> String:
	var readable := readable_name(tool_name)
	if readable.is_empty():
		return empty_default
	return String(readable.split(" ", false)[0]).left(max_length).to_upper()


static func glyph(tool_name: String) -> String:
	var normalized := tool_name.to_lower()
	if "read" in normalized:
		return "R"
	if "write" in normalized or "edit" in normalized:
		return "W"
	if "shell" in normalized or "bash" in normalized or "exec" in normalized:
		return ">_"
	if "search" in normalized or "find" in normalized or "grep" in normalized:
		return "?"
	if "web" in normalized or "fetch" in normalized:
		return "@"
	return title_name(tool_name).left(2).to_upper()
