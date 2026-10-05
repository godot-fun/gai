class_name VisualType
extends RefCounted

## Visual presentation selected for an agent run.

enum Type {
	NONE,
	JARVIS,
	TRANSFORMER,
	REASONING_TREE,
	TOOL_CONSTELLATION,
}


static func is_valid(value: int) -> bool:
	return value >= Type.NONE and value <= Type.TOOL_CONSTELLATION
