class_name VisualType
extends RefCounted

## Visual presentation selected for an agent run.

enum Type {
	NONE,
	JARVIS,
	TRANSFORMER,
	REASONING_TREE,
	TOOL_CONSTELLATION,
	CONTEXT_MEMORY_RIVER,
}


static func is_valid(value: int) -> bool:
	return value >= Type.NONE and value <= Type.CONTEXT_MEMORY_RIVER
