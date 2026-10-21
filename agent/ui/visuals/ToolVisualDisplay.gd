class_name ToolVisualDisplay
extends RefCounted

## Shared tool name and glyph display strings for agent visual effects.
## Use [method glyph] for compact symbol/text marks, [method glyph_emoji] for emoji icons.


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
	match tool_name:
		ReadTool.NAME:
			return "R"
		WriteTool.NAME:
			return "W"
		EditTool.NAME:
			return "E"
		BashTool.NAME:
			return ">_"
		ImageToTextTool.NAME:
			return "IM"
		AudioToTextTool.NAME:
			return "AU"
		DeleteTool.NAME:
			return "X"
		GrepTool.NAME:
			return "?"
		GlobTool.NAME:
			return "*"
		ListDirTool.NAME:
			return "/"
		WebFetchTool.NAME:
			return "@"
		WebSearchTool.NAME:
			return "#"
		_:
			return title_name(tool_name).left(2).to_upper()


static func glyph_emoji(tool_name: String) -> String:
	match tool_name:
		ReadTool.NAME:
			return "📚"
		WriteTool.NAME:
			return "✍️"
		EditTool.NAME:
			return "✂️"
		BashTool.NAME:
			return "🐚"
		ImageToTextTool.NAME:
			return "📸"
		AudioToTextTool.NAME:
			return "🎙️"
		DeleteTool.NAME:
			return "🗑"
		GrepTool.NAME:
			return "🕵️"
		GlobTool.NAME:
			return "🪄"
		ListDirTool.NAME:
			return "📂"
		WebFetchTool.NAME:
			return "📥"
		WebSearchTool.NAME:
			return "🌐"
		_:
			return "🤖"
