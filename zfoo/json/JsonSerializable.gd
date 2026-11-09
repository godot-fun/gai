@abstract
class_name JsonSerializable
extends RefCounted

## Serializes this object to a JSON string.
func to_json() -> String:
	return StringUtils.EMPTY


## Restores this object from a JSON string.
func from_json(_json: String) -> void:
	pass
