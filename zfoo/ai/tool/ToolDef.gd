@abstract
class_name ToolDef
extends RefCounted

## Chat Completions-compatible `tools[]` schema entry ([FunctionToolDef] or MCP-backed definitions).

## User-defined tools (`function` JSON schema or `custom` free-form input).
const TYPE_FUNCTION := "function"
const TYPE_CUSTOM := "custom"
## Responses API hosted tools.
const TYPE_WEB_SEARCH := "web_search"
const TYPE_WEB_SEARCH_PREVIEW := "web_search_preview"
const TYPE_FILE_SEARCH := "file_search"
const TYPE_MCP := "mcp"
const TYPE_TOOL_SEARCH := "tool_search"
## Assistants / preview hosted tools (legacy or provider-specific).
const TYPE_CODE_INTERPRETER := "code_interpreter"
const TYPE_COMPUTER_USE_PREVIEW := "computer_use_preview"

var type: String = TYPE_FUNCTION
