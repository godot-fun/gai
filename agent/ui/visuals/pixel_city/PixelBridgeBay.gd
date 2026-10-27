class_name PixelBridgeBay
extends Node2D

var bay_index: int = 0
var pixel: float = 4.0
var bay_width: float = 80.0
var truss_drop: float = 48.0
var bridge_color := Color.WHITE
var elapsed: float = 0.0

var truss_frame: Line2D
var pillar: ColorRect
var light_glow: ColorRect
var light_lamp: ColorRect
var light_post: ColorRect

var built_pixel := -1.0
var built_width := -1.0
var built_drop := -1.0
var built_index := -2147483648
var built_dark_theme := false


func configure(index: int, new_pixel: float, width: float, drop: float, color: Color, new_elapsed: float) -> void:
	bay_index = index
	pixel = new_pixel
	bay_width = width
	truss_drop = drop
	bridge_color = color
	elapsed = new_elapsed
	ensure_nodes()
	var dark_theme := ThemeColor.is_dark_theme()
	var geometry_dirty := not is_equal_approx(built_pixel, pixel) or not is_equal_approx(built_width, bay_width) or not is_equal_approx(built_drop, truss_drop) or built_index != bay_index or built_dark_theme != dark_theme
	if geometry_dirty:
		rebuild_geometry(dark_theme)
		built_pixel = pixel
		built_width = bay_width
		built_drop = truss_drop
		built_index = bay_index
		built_dark_theme = dark_theme
	apply_colors(dark_theme)
	update_light_pulse()
	pass


func ensure_nodes() -> void:
	if truss_frame != null:
		return
	truss_frame = Line2D.new()
	truss_frame.name = "Truss"
	truss_frame.joint_mode = Line2D.LINE_JOINT_SHARP
	truss_frame.begin_cap_mode = Line2D.LINE_CAP_NONE
	truss_frame.end_cap_mode = Line2D.LINE_CAP_NONE
	truss_frame.antialiased = false
	truss_frame.z_index = 1
	pillar = make_rect("Pillar")
	pillar.z_index = 0
	light_glow = make_rect("LightGlow")
	light_lamp = make_rect("LightLamp")
	light_post = make_rect("LightPost")
	light_glow.z_index = 3
	light_post.z_index = 3
	light_lamp.z_index = 4
	add_child(pillar)
	add_child(truss_frame)
	add_child(light_glow)
	add_child(light_post)
	add_child(light_lamp)
	pass


func make_rect(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func deck_height() -> float:
	return pixel * 4.0


func has_pier() -> bool:
	return posmod(bay_index, PixelBridgeLayer.PIER_EVERY_BAYS) == 0


func rebuild_geometry(dark_theme: bool) -> void:
	var deck_h := deck_height()
	var apex := Vector2(bay_width * 0.5, deck_h + truss_drop)
	truss_frame.width = pixel
	truss_frame.points = PackedVector2Array([
		Vector2(0.0, deck_h),
		apex,
		Vector2(bay_width, deck_h),
	])
	var show_pier := has_pier()
	pillar.visible = show_pier
	light_glow.visible = show_pier
	light_lamp.visible = show_pier
	light_post.visible = show_pier
	if show_pier:
		var pier_x := snappedf(bay_width * 0.5, pixel) - pixel
		var pier_center := pier_x + pixel
		pillar.position = Vector2(pier_x, deck_h)
		pillar.size = Vector2(pixel * 2.0, truss_drop + pixel * 10.0)
		light_lamp.position = Vector2(pier_x - pixel * 0.5, -pixel * 5.0)
		light_lamp.size = Vector2(pixel * 3.0, pixel)
		light_glow.position = Vector2(pier_x - pixel * 2.0, -pixel * 6.0)
		light_glow.size = Vector2(pixel * 4.0, pixel * 3.0)
		light_post.position = Vector2(pier_center - pixel * 0.5, -pixel * 4.0)
		light_post.size = Vector2(pixel, pixel * 4.0)
	pass


func apply_colors(dark_theme: bool) -> void:
	var alpha := 0.34 if dark_theme else 0.22
	truss_frame.default_color = Color(bridge_color, alpha * 0.72)
	if pillar.visible:
		pillar.color = Color(bridge_color, alpha * 0.62)
		light_post.color = Color(bridge_color, 0.28)
	pass


func update_light_pulse() -> void:
	if not light_lamp.visible:
		return
	var pulse := 0.94 + 0.06 * sin(elapsed * 1.35 + float(bay_index) * 0.7)
	light_glow.color = Color(bridge_color, 0.035 * pulse)
	light_lamp.color = Color(1.0, 0.76, 0.34, 0.48 * pulse)
	pass
