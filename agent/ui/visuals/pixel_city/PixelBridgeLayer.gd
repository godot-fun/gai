class_name PixelBridgeLayer
extends Node2D

const PARALLAX_FACTOR := 0.65
const BAY_WIDTH_RATIO := 20.0
const PIER_EVERY_BAYS := 3

var bays: Array[PixelBridgeBay] = []
var deck_top: ColorRect
var deck_rim: ColorRect

var viewport_size := Vector2.ZERO
var pixel: float = 4.0
var layer_scroll: float = 0.0
var elapsed: float = 0.0
var truss_drop: float = 0.0
var bridge_color := Color.WHITE

var built_viewport := Vector2.ZERO
var built_pixel := -1.0
var built_dark_theme := false


func update_visual(viewport_size_in: Vector2, pixel_in: float, camera_x: float, elapsed_in: float) -> void:
	viewport_size = viewport_size_in
	pixel = pixel_in
	layer_scroll = camera_x * PARALLAX_FACTOR
	elapsed = elapsed_in
	var road_y := snappedf(viewport_size.y * PixelCity.BRIDGE_TOP_RATIO + pixel * 7.0, pixel)
	var bottom := snappedf(viewport_size.y * 0.92, pixel)
	position = Vector2(0.0, road_y)
	truss_drop = maxf(pixel * 6.0, bottom - road_y - deck_height())
	bridge_color = VisualColor.appearance_color(ThemeColor.accent_theme_color(), -0.04, 0.72, 0.82)
	ensure_deck_nodes()
	sync_deck()
	var bay_width := pixel * BAY_WIDTH_RATIO
	var desired_count := ceili(viewport_size.x / bay_width) + 3
	ensure_bays(desired_count)
	var offset := fposmod(layer_scroll, bay_width)
	var first_bay_index := floori(layer_scroll / bay_width) - 1
	for pool_index in range(bays.size()):
		var bay := bays[pool_index]
		var world_index := first_bay_index + pool_index
		bay.position.x = float(pool_index - 1) * bay_width - offset
		bay.configure(world_index, pixel, bay_width, truss_drop, bridge_color, elapsed)
	pass


func deck_height() -> float:
	return pixel * 4.0


func ensure_deck_nodes() -> void:
	if deck_top != null:
		return
	deck_top = ColorRect.new()
	deck_top.name = "DeckTop"
	deck_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_top.z_index = 1
	deck_rim = ColorRect.new()
	deck_rim.name = "DeckRim"
	deck_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_rim.z_index = 1
	add_child(deck_top)
	add_child(deck_rim)
	pass


func sync_deck() -> void:
	var deck_h := deck_height()
	var bay_width := pixel * BAY_WIDTH_RATIO
	var dark_theme := ThemeColor.is_dark_theme()
	var alpha := 0.34 if dark_theme else 0.22
	var deck_dirty := viewport_size != built_viewport or not is_equal_approx(pixel, built_pixel) or built_dark_theme != dark_theme
	if not deck_dirty:
		deck_top.color = Color(bridge_color, alpha)
		deck_rim.color = Color(bridge_color, alpha * 0.74)
		return
	built_viewport = viewport_size
	built_pixel = pixel
	built_dark_theme = dark_theme
	deck_top.position = Vector2.ZERO
	deck_top.size = Vector2(viewport_size.x + bay_width, deck_h)
	deck_top.color = Color(bridge_color, alpha)
	deck_rim.position = Vector2(0.0, pixel * 3.0)
	deck_rim.size = Vector2(viewport_size.x + bay_width, pixel)
	deck_rim.color = Color(bridge_color, alpha * 0.74)
	pass


func ensure_bays(count: int) -> void:
	while bays.size() < count:
		var bay := PixelBridgeBay.new()
		bay.name = "Bay_%02d" % bays.size()
		bay.z_index = 2
		add_child(bay)
		bays.append(bay)
	while bays.size() > count:
		var bay: PixelBridgeBay = bays.pop_back()
		bay.queue_free()
	pass
