@abstract
class_name IJsonSerializable
extends RefCounted

## Serializes this object to a JSON string.
func to_json() -> String:
	return JsonSerializer.serialize_object(self)


## Restores this object from a parsed JSON dictionary.
func from_json(_data: Dictionary) -> void:
	pass
