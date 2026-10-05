class_name TimeUtils
extends Object

const NANO_PER_SECOND: int = 1_000_000_000

const MILLIS_PER_SECOND: int = 1 * 1000
const MILLIS_PER_SECOND_5: int = 5 * 1000
const MILLIS_PER_SECOND_10: int = 10 * 1000
const MILLIS_PER_MINUTE: int = 1 * 60 * MILLIS_PER_SECOND

const MILLIS_PER_HOUR: int = 1 * 60 * MILLIS_PER_MINUTE
const MILLIS_PER_HOUR_8: int = 8 * 60 * MILLIS_PER_MINUTE
const MILLIS_PER_DAY: int = 1 * 24 * MILLIS_PER_HOUR
const MILLIS_PER_WEEK: int = 1 * 7 * MILLIS_PER_DAY

static var offset_from_uts = Time.get_time_zone_from_system().bias * MILLIS_PER_MINUTE

static var _timestamp: int = current_time_millis()
## Returns the last cached timestamp in milliseconds (updated by current_time_millis / second tick).
static func now() -> int:
	return _timestamp

## Returns the current system timestamp in milliseconds, and refreshes the now() cache.
static func current_time_millis() -> int:
	_timestamp = (Time.get_unix_time_from_system() * MILLIS_PER_SECOND) as int
	return _timestamp

## Returns local datetime string "YYYY-MM-DD HH:MM:SS" for timestamp (ms since Unix epoch).
static func time_to_datetime_string(timestamp: int) -> String:
	return Time.get_datetime_string_from_unix_time(((timestamp + offset_from_uts) / (MILLIS_PER_SECOND as float)) as int, true)

## Returns local date string "YYYY-MM-DD" for timestamp (ms since Unix epoch).
static func time_to_date_string(timestamp: int) -> String:
	return Time.get_date_string_from_unix_time(((timestamp + offset_from_uts) / (MILLIS_PER_SECOND as float)) as int)

# ----------------------------------------------------------------------------------------------------------------------
## Returns the system local datetime string "yyyy-mm-dd hh:mm:ss" (now).
static func date() -> String:
	return Time.get_datetime_string_from_system(false, true)
# ----------------------------------------------------------------------------------------------------------------------
## Returns "MM-DD HH:MM" for timestamp (ms); returns "" when timestamp <= 0.
static func date_mmddhhmm(timestamp: int) -> String:
	if timestamp <= 0:
		return ""
	var s := TimeUtils.time_to_datetime_string(timestamp)
	var segs := s.split(" ", false, 1)
	if segs.size() < 2:
		return s
	var ymd := segs[0].split("-")
	if ymd.size() < 3:
		return s
	var hms := segs[1]
	var hm := hms.substr(0, mini(5, hms.length()))
	return StringUtils.format("{}-{} {}", ymd[1], ymd[2], hm)


## Returns "MM-DD" for timestamp (ms); returns "" when timestamp <= 0.
static func date_mmdd(timestamp: int) -> String:
	if timestamp <= 0:
		return ""
	var s := TimeUtils.time_to_datetime_string(timestamp)
	var segs := s.split(" ", false, 1)
	if segs.size() < 2:
		return s
	var ymd := segs[0].split("-")
	if ymd.size() < 3:
		return s
	return StringUtils.format("{}-{}", ymd[1], ymd[2])

## Returns relative time text for ctime (ms), e.g. "Just now", "5m ago", "2h ago", "3d ago"; future times use date_mmddhhmm; returns EMPTY when ctime <= 0.
static func date_ago(ctime: int) -> String:
	if ctime <= 0:
		return StringUtils.EMPTY
	var delta_ms: int = TimeUtils.current_time_millis() - ctime
	if delta_ms < 0:
		return date_mmddhhmm(ctime)
	@warning_ignore("integer_division")
	var delta_sec: int = delta_ms / TimeUtils.MILLIS_PER_SECOND
	if delta_sec < 60:
		return "Just now"
	if delta_sec < 3600:
		@warning_ignore("integer_division")
		return StringUtils.format("{}m ago", delta_sec / 60)
	if delta_sec < 86400:
		@warning_ignore("integer_division")
		return StringUtils.format("{}h ago", delta_sec / 3600)
	@warning_ignore("integer_division")
	return StringUtils.format("{}d ago", delta_sec / 86400)
