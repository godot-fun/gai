class_name VisualType
extends RefCounted

## Visual presentation selected for an agent run.

enum Type {
	NONE,
	JARVIS,
	PROCEDURE,
}


static func is_valid(value: int) -> bool:
	return value >= Type.NONE and value <= Type.PROCEDURE
