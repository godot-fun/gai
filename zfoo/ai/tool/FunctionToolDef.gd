class_name FunctionToolDef
extends ToolDef

## Builtin agent tool schema (`tools[].type: function`).

var function: FunctionDef = FunctionDef.new()


class FunctionDef:
	var name: String = ""
	var description: String = ""
	var parameters: ToolParameters.Parameters = ToolParameters.Parameters.new()
