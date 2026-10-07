class_name RandomUtils
extends Object


const MIN_INT: int = -2147483648
const MAX_INT: int = 2147483647

# Letters, digits and the common English symbols (printable ASCII without whitespace).
const RANDOM_STRING_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"

static func random_boolean() -> bool:
	return 1 == randi_range(0, 2)


# [-2^32, 2^32)
static func random_int() -> int:
	return random_int_range(MIN_INT, MAX_INT)

# [0,limit)
static func random_int_limit(limit: int) -> int:
	return random_int_range(0, limit)

# [-2^32, 2^32)
static func random_int_range(from: int, to: int) -> int:
	if from < MIN_INT:
		push_error(StringUtils.format("from [{}] shoud be >= [{}]", from, MIN_INT))
		return 0
	
	if to > MAX_INT:
		push_error(StringUtils.format("to [{}] should be <= [{}]", from, MAX_INT))
		return 0
	
	return randi_range(from, to - 1)

static func random_ele(array: Array) -> Variant:
	return array[random_int_limit(array.size())]

# Generate a random string with the given character count.
static func random_string(length: int, chars: String = RANDOM_STRING_CHARS) -> String:
	if length <= 0:
		return ""
	if chars.is_empty():
		push_error("chars should not be empty")
		return ""
	
	var builder := StringBuilder.new()
	for _i in length:
		builder.append(chars[random_int_limit(chars.length())])
	return builder.build_string()


# Generate a random position inside a circle.
static func random_circle(center: Vector2, radius: float) -> Vector2:
	var angle := randf_range(0, TAU)  # TAU = 2π
	var r := randf() * radius
	var offset := Vector2(r * cos(angle), r * sin(angle))
	return center + offset

# Generate a random position on a circle.
static func random_on_circle(center: Vector2, radius: float) -> Vector2:
	var angle := randf_range(0, TAU)  # TAU = 2π
	var offset := Vector2(radius * cos(angle), radius * sin(angle))
	return center + offset

static func random_on_circle_range(center: Vector2, radius: float, start_angle: float, end_angle: float) -> Vector2:
	var angle := randf_range(start_angle, end_angle)
	var offset := Vector2(radius * cos(angle), radius * sin(angle))
	return center + offset
