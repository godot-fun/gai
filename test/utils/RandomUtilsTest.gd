
const SAMPLE_TIMES: int = 1000


# Sample [param sampler] [constant SAMPLE_TIMES] times and assert every result stays inside [from, to].
func assert_samples_within(sampler: Callable, from: float, to: float) -> void:
	for i in SAMPLE_TIMES:
		var value: float = sampler.call()
		assert(value >= from and value < to)
	pass


static func RandomUtils_random_int_limit_one_test() -> void:
	# [0, 1) always collapses to 0, and a single-element range has only one legal value.
	for i in SAMPLE_TIMES:
		assert(RandomUtils.random_int_limit(1) == 0)
		assert(RandomUtils.random_int_range(7, 8) == 7)
	pass


func RandomUtils_random_int_limit_in_range_test() -> void:
	assert_samples_within(func() -> int: return RandomUtils.random_int_limit(10), 0, 10)
	pass


func RandomUtils_random_int_range_in_bounds_test() -> void:
	assert_samples_within(func() -> int: return RandomUtils.random_int_range(-5, 5), -5, 5)
	assert_samples_within(func() -> int: return RandomUtils.random_int_range(7, 8), 7, 8)
	pass


func RandomUtils_random_boolean_test() -> void:
	var seen := {}
	for i in SAMPLE_TIMES:
		seen[RandomUtils.random_boolean()] = true
	assert(seen.has(true) and seen.has(false))
	pass


func RandomUtils_random_ele_test() -> void:
	var pool := ["a", "b", "c"]
	for i in 100:
		assert(pool.has(RandomUtils.random_ele(pool)))
	pass


func RandomUtils_random_string_test() -> void:
	assert(RandomUtils.random_string(0) == StringUtils.EMPTY)
	assert(RandomUtils.random_string(-3) == StringUtils.EMPTY)
	var text := RandomUtils.random_string(24)
	assert(text.length() == 24)
	for c in text:
		assert(RandomUtils.RANDOM_STRING_CHARS.contains(c))
	assert(RandomUtils.random_string(8, "ab").length() == 8)
	pass


func RandomUtils_random_char_at_deterministic_test() -> void:
	var first := RandomUtils.random_char_at(7, 3, 1)
	assert(first == RandomUtils.random_char_at(7, 3, 1))
	assert(first.length() == 1)
	assert(RandomUtils.RANDOM_STRING_CHARS.contains(first))
	pass


func RandomUtils_random_circle_and_on_circle_test() -> void:
	var center := Vector2(10, 20)
	assert(is_equal_approx(RandomUtils.random_on_circle(center, 5.0).distance_to(center), 5.0))
	assert(RandomUtils.random_circle(center, 5.0).distance_to(center) <= 5.0001)
	pass


func RandomUtils_random_on_circle_range_angle_test() -> void:
	var center := Vector2.ZERO
	var start_angle := 0.0
	var end_angle := PI * 0.5
	for i in SAMPLE_TIMES:
		var point := RandomUtils.random_on_circle_range(center, 4.0, start_angle, end_angle)
		assert(is_equal_approx(point.length(), 4.0))
		var angle := point.angle()
		assert(angle >= start_angle - 0.0001 and angle <= end_angle + 0.0001)
	pass


func RandomUtils_random_circle_zero_radius_test() -> void:
	assert(RandomUtils.random_circle(Vector2(3, 4), 0.0).is_equal_approx(Vector2(3, 4)))
	pass
