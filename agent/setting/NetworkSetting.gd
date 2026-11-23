class_name NetworkSetting
extends RefCounted

## Persistent network settings shared by HTTP and AI requests.

const PROXY_ADDRESS_KEY := "proxy_address"


static func get_proxy_address() -> String:
	return Setting.get_string(PROXY_ADDRESS_KEY).strip_edges()


static func save_proxy_address(proxy_address: String) -> void:
	var normalized_proxy_address := proxy_address.strip_edges()
	if normalized_proxy_address != get_proxy_address():
		Setting.set_string(PROXY_ADDRESS_KEY, normalized_proxy_address)
		Setting.save()
		AgentEvents.events.proxy_address_changed.emit()
	pass
