@abstract
class_name IJsonSerializable
extends RefCounted

## Serializes this object to a JSON string.
func serialize() -> String:
	return JsonSerializer.serialize_object(self)


## Restores this object from a parsed JSON dictionary and returns the deserialized value.
func deserialize(_data: Dictionary) -> Variant:
	return self
