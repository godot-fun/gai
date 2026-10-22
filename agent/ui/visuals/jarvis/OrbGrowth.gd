class_name OrbGrowth
extends RefCounted

## Maps cumulative streamed text volume to neuron mesh density.

const NEURON_MIN := 128
const NEURON_MAX := 512
const NEURON_REBUILD_STEP := 96
## Stream chars to reach maximum density (one long agent reply).
const CHARS_FOR_FULL := 7000.0

## Min seconds between heavy neuron/filament mesh rebuilds.
const NEURON_REBUILD_COOLDOWN_S := 0.55


static func level(char_count: int) -> float:
	return clampf(float(char_count) / CHARS_FOR_FULL, 0.0, 1.0)


static func neuron_count(char_count: int) -> int:
	return int(lerpf(float(NEURON_MIN), float(NEURON_MAX), level(char_count)))
