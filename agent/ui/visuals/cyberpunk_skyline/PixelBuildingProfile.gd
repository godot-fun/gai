class_name PixelBuildingProfile
extends RefCounted

## A mixed-radix profile gives every world building a stable combination instead
## of independently rolling a small set of templates. The permutation is bijective
## across PROFILE_CYCLE consecutive indices, so complete profiles do not repeat.

enum Shape { SLAB, STEPPED, TWIN, CROWN, TOWER, TERRACED, NOTCHED }
enum Roof { NONE, ANTENNA, CAP, WATER_TANK, TWIN_MAST }
enum Facade { GRID, WIDE_BANDS, NARROW_COLUMNS, OFFSET_GRID }
enum ShadowSide { LEFT, RIGHT }

const SETBACK_VARIANTS := 3
const TINT_VARIANTS := 4
const WINDOW_RHYTHM_VARIANTS := 4
const SHAPE_VARIANTS := 7
const ROOF_VARIANTS := 5
const FACADE_VARIANTS := 4
const SHADOW_VARIANTS := 2
const PROFILE_CYCLE := SHAPE_VARIANTS * ROOF_VARIANTS * FACADE_VARIANTS * SHADOW_VARIANTS * SETBACK_VARIANTS * TINT_VARIANTS * WINDOW_RHYTHM_VARIANTS
const PROFILE_STEP := 48271

var signature: int = 0
var world_index: int = 0
var distant: bool = false
var shape: Shape = Shape.SLAB
var roof: Roof = Roof.NONE
var facade: Facade = Facade.GRID
var shadow_side: ShadowSide = ShadowSide.RIGHT
var setback_variant: int = 0
var tint_variant: int = 0
var window_rhythm: int = 0
var width_steps: int = 0


func _init(index: int = 0, is_distant: bool = false) -> void:
	world_index = index
	distant = is_distant
	var code := posmod(index * PROFILE_STEP + (7919 if is_distant else 0), PROFILE_CYCLE)
	signature = code
	shape = (code % SHAPE_VARIANTS) as Shape
	code = floori(float(code) / float(SHAPE_VARIANTS))
	roof = (code % ROOF_VARIANTS) as Roof
	code = floori(float(code) / float(ROOF_VARIANTS))
	facade = (code % FACADE_VARIANTS) as Facade
	code = floori(float(code) / float(FACADE_VARIANTS))
	shadow_side = (code % SHADOW_VARIANTS) as ShadowSide
	code = floori(float(code) / float(SHADOW_VARIANTS))
	setback_variant = code % SETBACK_VARIANTS
	code = floori(float(code) / float(SETBACK_VARIANTS))
	tint_variant = code % TINT_VARIANTS
	code = floori(float(code) / float(TINT_VARIANTS))
	window_rhythm = code % WINDOW_RHYTHM_VARIANTS
	width_steps = posmod(floori(float(signature) / 97.0), 4)
	pass


func dark_floor_period() -> int:
	return 4 + window_rhythm


func dark_floor_phase() -> int:
	return posmod(floori(float(signature) / 29.0), dark_floor_period())
