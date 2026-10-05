
func ArrayUtils_test() -> void:
	var array: Array[int] = []
	assert(ArrayUtils.is_empty(array))
	array.append(1)
	assert(ArrayUtils.is_not_empty(array))
	pass


func CollectionUtils_test() -> void:
	var map: Dictionary[int, int] = {}
	assert(CollectionUtils.is_empty(map))
	map[1] = 100
	assert(CollectionUtils.is_not_empty(map))
	pass


func RandomUtils_test() -> void:
	var boolValue := RandomUtils.random_boolean()
	if boolValue:
		assert(boolValue == true)
	else:
		assert(boolValue == false)
	var intValue := RandomUtils.random_int()
	assert(intValue < RandomUtils.MAX_INT)
	assert(intValue >= RandomUtils.MIN_INT)
	var intLimitValue := RandomUtils.random_int_limit(100)
	assert(intLimitValue >= 0)
	var negativeIntValue := RandomUtils.random_int_range(-100, -1)
	assert(negativeIntValue < 0)
	var array: Array[int] = [1, 2, 3]
	var randomElement = RandomUtils.random_ele(array)
	assert(array.find(randomElement) >= 0)
	pass



func TimeUtils_test() -> void:
	assert(TimeUtils.MILLIS_PER_MINUTE == 60 * TimeUtils.MILLIS_PER_SECOND)
	assert(TimeUtils.MILLIS_PER_HOUR == 60 * TimeUtils.MILLIS_PER_MINUTE)
	assert(TimeUtils.MILLIS_PER_DAY == 24 * TimeUtils.MILLIS_PER_HOUR)
	assert(TimeUtils.MILLIS_PER_WEEK == 7 * TimeUtils.MILLIS_PER_DAY)

	var timestamp := TimeUtils.current_time_millis()
	# YYYY-MM-DD HH:MM:SS
	var dateTimeStr := Time.get_datetime_string_from_system(false, true)
	assert(dateTimeStr == TimeUtils.time_to_datetime_string(timestamp))
	assert(dateTimeStr.split(" ")[0] == TimeUtils.time_to_date_string(timestamp))

	var now := TimeUtils.now()
	await ThreadUtils.async_sleep(2000)
	assert(now != TimeUtils.now())
	pass
