class_name RateLimitUtils
extends Object


static var last_limit_millis_100: int = 0
static var last_limit_millis_200: int = 0
static var last_limit_millis_300: int = 0
static var last_limit_millis_400: int = 0
static var last_limit_millis_500: int = 0
static var last_limit_millis_600: int = 0
static var last_limit_second_1: int = 0
static var last_limit_second_2: int = 0
static var last_limit_second_3: int = 0

static func limit_millis_100() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_100 < 100:
		return true

	last_limit_millis_100 = ticks
	return false


static func limit_millis_200() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_200 < 200:
		return true

	last_limit_millis_200 = ticks
	return false


static func limit_millis_300() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_300 < 300:
		return true

	last_limit_millis_300 = ticks
	return false


static func limit_millis_400() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_400 < 400:
		return true

	last_limit_millis_400 = ticks
	return false


static func limit_millis_500() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_500 < 500:
		return true

	last_limit_millis_500 = ticks
	return false


static func limit_millis_600() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_millis_600 < 600:
		return true

	last_limit_millis_600 = ticks
	return false


static func limit_second_1() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_second_1 < TimeUtils.MILLIS_PER_SECOND:
		return true

	last_limit_second_1 = ticks
	return false


static func limit_second_2() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_second_2 < 2 * TimeUtils.MILLIS_PER_SECOND:
		return true

	last_limit_second_2 = ticks
	return false


static func limit_second_3() -> bool:
	var ticks := Time.get_ticks_msec()

	if ticks - last_limit_second_3 < 3 * TimeUtils.MILLIS_PER_SECOND:
		return true

	last_limit_second_3 = ticks
	return false
