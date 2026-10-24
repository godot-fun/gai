class_name ToolHelper
extends Object


static func is_file_tool(tool_name: String) -> bool:
	return (
		tool_name == ReadTool.NAME
		or tool_name == WriteTool.NAME
		or tool_name == EditTool.NAME
		or tool_name == DeleteTool.NAME
	)


static func is_web_tool(tool_name: String) -> bool:
	return tool_name == WebSearchTool.NAME or tool_name == WebFetchTool.NAME


static func get_tool_call_summary(tool_name: String, args: Dictionary[String, Variant]) -> String:
	var body := ""
	match tool_name:
		GrepTool.NAME:
			body = str(args.get(GrepTool.ARG_PATTERN, ""))
		GlobTool.NAME:
			body = str(args.get(GlobTool.ARG_PATTERN, ""))
		ListDirTool.NAME:
			body = str(args.get(ListDirTool.ARG_PATH, ""))
		BashTool.NAME:
			body = str(args.get(BashTool.ARG_COMMAND, ""))
		ReadImageTool.NAME:
			body = str(args.get(ReadImageTool.ARG_PATH, ""))
			var image_prompt := str(args.get(ReadImageLocalTool.ARG_PROMPT, "")).strip_edges()
			if StringUtils.is_not_blank(image_prompt):
				body += FileUtils.NEWLINE_LF + image_prompt
		AudioToTextTool.NAME:
			body = str(args.get(AudioToTextTool.ARG_PATH, ""))
		WebSearchTool.NAME:
			body = str(args.get(WebSearchTool.ARG_QUERY, ""))
		WebFetchTool.NAME:
			body = str(args.get(WebFetchTool.ARG_URL, ""))
		_:
			for key: Variant in args.keys():
				var value := str(args[key])
				if StringUtils.is_not_blank(value):
					body = value
					break
	return body
