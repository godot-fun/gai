class_name PixelCloud
extends Node2D

var pixel: float = 4.0
var cloud_width: float = 80.0
var opacity: float = 0.1


func configure(new_pixel: float, new_width: float, new_opacity: float) -> void:
	pixel = new_pixel
	cloud_width = new_width
	opacity = new_opacity
	queue_redraw()
	pass


func _draw() -> void:
	var color := Color(0.72, 0.79, 0.86, opacity)
	draw_rect(Rect2(0.0, 0.0, snappedf(cloud_width, pixel), pixel * 3.0), color)
	draw_rect(Rect2(snappedf(cloud_width * 0.18, pixel), -pixel * 2.0, snappedf(cloud_width * 0.38, pixel), pixel * 2.0), color)
	pass
