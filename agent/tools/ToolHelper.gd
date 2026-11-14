class_name ToolHelper
extends Object


static func is_file_tool(tool_name: String) -> bool:
	return (
		tool_name == ReadTool.NAME
		or tool_name == ReadImageTool.NAME
		or tool_name == WriteTool.NAME
		or tool_name == EditTool.NAME
		or tool_name == DeleteTool.NAME
	)


static func is_explorer_tool(tool_name: String) -> bool:
	return (
		tool_name == GlobTool.NAME
		or tool_name == GrepTool.NAME
		or tool_name == ListDirTool.NAME
	)


static func is_web_tool(tool_name: String) -> bool:
	return (
		tool_name == WebSearchTool.NAME
		or tool_name == WebFetchTool.NAME
		or tool_name == BrowserOpenTool.NAME
		or tool_name == BrowserObserveTool.NAME
		or tool_name == BrowserActTool.NAME
	)


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
		AudioToTextTool.NAME:
			body = str(args.get(AudioToTextTool.ARG_PATH, ""))
		WebSearchTool.NAME:
			body = str(args.get(WebSearchTool.ARG_QUERY, ""))
		WebFetchTool.NAME:
			body = str(args.get(WebFetchTool.ARG_URL, ""))
		BrowserOpenTool.NAME:
			body = str(args.get(BrowserOpenTool.ARG_URL, ""))
		BrowserObserveTool.NAME:
			body = str(args.get(BrowserObserveTool.ARG_MODE, BrowserStepHelper.MODE_ELEMENTS))
		BrowserActTool.NAME:
			# The first step is what the call is about; a missing or invalid batch summarizes as nothing.
			var raw_steps: Variant = args.get(BrowserActTool.ARG_STEPS, [])
			if typeof(raw_steps) == TYPE_ARRAY:
				var batch := BrowserStepHelper.normalize_steps(raw_steps)
				if not batch.steps.is_empty():
					var step: BrowserStep = batch.steps[0]
					body = step.action
					for detail: String in [step.ref, step.url, step.text, step.key, step.value]:
						if StringUtils.is_not_blank(detail):
							body = StringUtils.format("{} {}", step.action, detail)
							break
		_:
			for key: Variant in args.keys():
				var value := str(args[key])
				if StringUtils.is_not_blank(value):
					body = value
					break
	return body
