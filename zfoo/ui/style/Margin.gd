class_name Margin
extends Object

## Four-pixel spacing scale. Public values are recalculated from the immutable 100% design step.

const STEP := 4

static var ma_0: int = 0
static var ma_1: int = 4
static var ma_2: int = 8
static var ma_3: int = 12
static var ma_4: int = 16
static var ma_5: int = 20
static var ma_6: int = 24
static var ma_7: int = 28
static var ma_8: int = 32
static var ma_9: int = 36
static var ma_10: int = 40
static var ma_11: int = 44
static var ma_12: int = 48


static func apply_scale(scale: float) -> void:
	ma_0 = 0
	ma_1 = scaled_step(1, scale)
	ma_2 = scaled_step(2, scale)
	ma_3 = scaled_step(3, scale)
	ma_4 = scaled_step(4, scale)
	ma_5 = scaled_step(5, scale)
	ma_6 = scaled_step(6, scale)
	ma_7 = scaled_step(7, scale)
	ma_8 = scaled_step(8, scale)
	ma_9 = scaled_step(9, scale)
	ma_10 = scaled_step(10, scale)
	ma_11 = scaled_step(11, scale)
	ma_12 = scaled_step(12, scale)
	pass


static func scaled_step(step_count: int, scale: float) -> int:
	return DisplayScale.scale_int(STEP * step_count, scale)
