class_name NetUtils
extends Object

const LOCAL_LOOPBACK_IP: String = "127.0.0.1"
const PORT_RANGE_MIN: int = 1024
const PORT_RANGE_MAX: int = 65535

static func local_host() -> String:
	return IP.resolve_hostname(OS.get_environment("COMPUTERNAME"), IP.Type.TYPE_IPV4)


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
