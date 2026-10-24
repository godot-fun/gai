class_name HttpUtils
extends Object

const GOOGLE_CONNECTIVITY_CHECK_URL := "https://www.google.com/generate_204"
const CONNECTIVITY_CHECK_TIMEOUT_MILLIS := 5000


## Checks whether the current network can reach Google across the firewall.
## Uses Google's lightweight 204 endpoint; an optional proxy can be supplied for the check.
static func async_is_cross_firewall(timeout_millis: int = CONNECTIVITY_CHECK_TIMEOUT_MILLIS) -> bool:
	var response := await HttpHelper.async_get(GOOGLE_CONNECTIVITY_CHECK_URL, timeout_millis)
	return response.success and response.code == 204


static func is_https_url(url: String) -> bool:
	if StringUtils.is_blank(url):
		return false
	return url.strip_edges().begins_with("https://")

static func is_valid_http_url(url: String) -> bool:
	return url.begins_with("http://") || url.begins_with("https://")

# https://www.google.com -> www.google.com
static func get_host_from_url(url: String) -> String:
	var no_protocol := _remove_protocol(url)
	var slash_index := no_protocol.find("/")
	if slash_index != -1:
		no_protocol = no_protocol.substr(0, slash_index)

	var colon_index := no_protocol.find(":")
	if colon_index != -1:
		return no_protocol.substr(0, colon_index)

	return no_protocol


# https://www.google.com -> 443
# http://localhost:8080 -> 8080
static func get_port_from_url(url: String) -> int:
	var no_protocol := _remove_protocol(url)
	var slash_index := no_protocol.find("/")
	if slash_index != -1:
		no_protocol = no_protocol.substr(0, slash_index)

	var colon_index := no_protocol.find(":")
	if colon_index != -1:
		return int(no_protocol.substr(colon_index + 1))

	if is_https_url(url):
		return 443
	return 80


# https://www.google.com/search -> /search
static func get_path_from_url(url: String) -> String:
	var no_protocol := _remove_protocol(url)
	var slash_index := no_protocol.find("/")
	if slash_index != -1:
		return no_protocol.substr(slash_index)
	return "/"


static func has_header(headers: PackedStringArray, name: String) -> bool:
	var prefix := name.to_lower() + ":"
	for header: String in headers:
		if header.strip_edges().to_lower().begins_with(prefix):
			return true
	return false


## Resolves an absolute or relative URL reference against [param source_url].
static func resolve_redirect_url(source_url: String, location: String) -> String:
	var target := location.strip_edges()
	if is_valid_http_url(target):
		return target
	var scheme_end := source_url.find("://")
	if scheme_end < 0:
		return ""
	var scheme := source_url.substr(0, scheme_end)
	if target.begins_with("//"):
		return scheme + ":" + target
	var authority_start := scheme_end + 3
	var path_start := source_url.find("/", authority_start)
	var origin := source_url if path_start < 0 else source_url.substr(0, path_start)
	if target.begins_with("/"):
		return origin + target
	var source_path := "/" if path_start < 0 else source_url.substr(path_start)
	var query_index := source_path.find("?")
	if query_index >= 0:
		source_path = source_path.substr(0, query_index)
	var directory_end := source_path.rfind("/")
	var directory := "/" if directory_end < 0 else source_path.substr(0, directory_end + 1)
	return origin + directory + target


static func _remove_protocol(url: String) -> String:
	if url.begins_with("http://"):
		return url.substr(7)
	elif url.begins_with("https://"):
		return url.substr(8)
	return url
