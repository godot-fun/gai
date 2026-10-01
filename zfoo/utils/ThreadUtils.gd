class_name ThreadUtils
extends Object

# will block current thread
static func sleep(millis: int) -> void:
	OS.delay_msec(millis)
	pass

static func async_sleep(millis: int) -> void:
	var deadline := Time.get_ticks_msec() + maxi(millis, 0)
	while true:
		await Engine.get_main_loop().process_frame
		if Time.get_ticks_msec() >= deadline:
			break
	pass
