class_name StopWatch
extends RefCounted

var startTime: int = Time.get_ticks_msec()

func cost() -> int:
	return Time.get_ticks_msec() - startTime

func cost_seconds() -> float:
	var costSeconds: float = cost() / (TimeUtils.MILLIS_PER_SECOND as float)
	return snappedf(costSeconds, 0.01)

func cost_minutes() -> float:
	var costMinutes: float = cost() / (TimeUtils.MILLIS_PER_MINUTE as float)
	return snappedf(costMinutes, 0.01)
