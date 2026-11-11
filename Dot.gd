extends Control

@export var dot_color := Color(1.0, 0.8, 0.2)
@export var outline_color := Color(0.25, 0.12, 0.05)
@export var outline_width := 3.0

func _draw():
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(center, radius, outline_color)
	draw_circle(center, radius - outline_width, dot_color)
	
	
	
