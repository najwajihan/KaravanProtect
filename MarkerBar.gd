extends Control

@export var max_value := 100.0
@export var bar_width := 300.0
@export var bar_height := 12.0

var value := 100.0

@onready var track: ColorRect = $Track
@onready var fill: ColorRect = $Fill
@onready var marker: Control = $Marker

func _ready() -> void:
	
	var center_y := marker.size.y / 2.0
	track.position = Vector2(0.0, center_y - bar_height / 2.0)
	track.size = Vector2(bar_width, bar_height)
	fill.position = track.position
	fill.size = Vector2(bar_width, bar_height)
	_refresh()
	
func set_value(new_value: float):
	value = clampf(new_value, 0.0, max_value)
	_refresh()
	
func _refresh():
	
	var ratio := value / max_value
	fill.size.x = bar_width * ratio
	marker.position.x = bar_width * ratio - marker.size.x / 2.0
	marker.position.y = 0.0
