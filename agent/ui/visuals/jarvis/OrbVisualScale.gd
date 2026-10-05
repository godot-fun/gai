class_name OrbVisualScale
extends RefCounted

## Shared size tuning for the Jarvis orb overlay.

const WORLD_SCALE := 1.45
const CAMERA_DISTANCE := 4.05
const CAMERA_FOV := 56.0
## Char flight paths extend this much beyond the neural core (local units).
const PATH_EXTENT := 2.05

## Outer neuron shell band (must stay in sync with JarvisOrbNeuronNet shell generator).
const OUTER_SHELL_RADIUS_CENTER := 1.22
const OUTER_SHELL_RADIUS_SPREAD := 0.035
## Extra slack for shell ellipsoid stretch and point jitter.
const OUTER_SHELL_SHAPE_MARGIN := 0.14

static func outer_shell_extent_max() -> float:
	return OUTER_SHELL_RADIUS_CENTER + OUTER_SHELL_RADIUS_SPREAD + OUTER_SHELL_SHAPE_MARGIN


static func ring_radii() -> PackedFloat32Array:
	var base := outer_shell_extent_max()
	return PackedFloat32Array([base + 0.08, base + 0.24, base + 0.40])

## Floating keyword labels (seconds).
const KEYWORD_LIFE_MIN := 5.5
const KEYWORD_LIFE_MAX := 9.0
const KEYWORD_DRIFT_SPEED := 0.04

## Char particle path progress speed (lower = longer on screen).
const PARTICLE_SPEED_MIN := 0.15
const PARTICLE_SPEED_MAX := 0.28
