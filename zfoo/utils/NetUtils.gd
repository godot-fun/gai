class_name NetUtils
extends Object

const LOCAL_LOOPBACK_IP: String = "127.0.0.1"
const PORT_RANGE_MIN: int = 1024
const PORT_RANGE_MAX: int = 65535


## Returns a local IPv4 address. Resolves Windows and POSIX hostname variables first,
## then falls back to the first local interface address and finally loopback.
static func local_host() -> String:
	var hostname := OS.get_environment("COMPUTERNAME").strip_edges()
	if StringUtils.is_blank(hostname):
		hostname = OS.get_environment("HOSTNAME").strip_edges()
	if StringUtils.is_not_blank(hostname):
		var resolved := IP.resolve_hostname(hostname, IP.Type.TYPE_IPV4)
		if resolved.is_valid_ip_address():
			return resolved
	for address: String in IP.get_local_addresses():
		if address.is_valid_ip_address() and not address.contains(":"):
			return address
	return LOCAL_LOOPBACK_IP


## Finds the first bindable loopback TCP port at or above start_port, then releases the probe.
static func find_available_port(start_port: int) -> int:
	for port in range(maxi(start_port, PORT_RANGE_MIN), PORT_RANGE_MAX + 1):
		var probe := TCPServer.new()
		var error := probe.listen(port, LOCAL_LOOPBACK_IP)
		probe.stop()
		if error == OK:
			return port
	return -1


## TCP connect probe (like `telnet host port`). Returns true when the port accepts within timeout_millis.
static func telnet(host: String, port: int, timeout_millis: int = 3000) -> bool:
	if StringUtils.is_blank(host) or port < 1 or port > 65535:
		return false
	var tcp := StreamPeerTCP.new()
	var open := false
	if tcp.connect_to_host(host.strip_edges(), port) == OK:
		var deadline := Time.get_ticks_msec() + maxi(timeout_millis, 0)
		while Time.get_ticks_msec() < deadline:
			tcp.poll()
			match tcp.get_status():
				StreamPeerTCP.STATUS_CONNECTED:
					open = true
					break
				StreamPeerTCP.STATUS_ERROR:
					break
			await ThreadUtils.async_sleep(10)
	tcp.disconnect_from_host()
	return open
