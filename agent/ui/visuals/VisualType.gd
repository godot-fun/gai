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
	NEURAL_AURORA,
	SEMANTIC_BLACK_HOLE,
}


static func is_valid(value: int) -> bool:
	return value >= Type.NONE and value <= Type.SEMANTIC_BLACK_HOLE
