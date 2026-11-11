extends ColorRect

signal dropped

@export var cooldown_time := 0.5
@export var cost := 1

# Kalau nilai enabled diubah, tampilan kartu langsung ikut berubah
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_stop_drag()
		_update_visual()

# Kartu menggelap kalau koin tidak cukup
var affordable := true:
	set(value):
		affordable = value
		_update_visual()

var cooldown_left := 0.0
var is_dragging := false
var ghost: ColorRect = null

@onready var cost_label: Label = $CostLabel

func _ready():
	cost_label.text = str(cost)

func _process(delta):
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
		_update_visual()
	# Kotak bayangan mengikuti mouse selama kartu ditarik
	if is_dragging and ghost != null:
		ghost.position = get_viewport().get_mouse_position() - ghost.size / 2.0

func can_use() -> bool:
	return enabled and affordable and cooldown_left <= 0.0

func start_cooldown():
	cooldown_left = cooldown_time
	_update_visual()

func _gui_input(event):
	# Mulai menarik saat klik kiri ditekan di atas kartu
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_use():
			_start_drag()

func _input(event):
	# Dilepas di mana pun (tidak harus di atas kartu), jadi dicek lewat _input
	if is_dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_drag()
		dropped.emit()

func _start_drag():
	is_dragging = true
	ghost = ColorRect.new()
	ghost.size = Vector2(24, 24)
	ghost.color = Color(0.3, 0.5, 1.0, 0.6)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(ghost)

func _stop_drag():
	is_dragging = false
	if ghost != null:
		ghost.queue_free()
		ghost = null

func _update_visual():
	# Kartu menggelap saat cooldown, saat koin kurang, atau saat berada di peran penjaga lentera
	if can_use():
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(0.5, 0.5, 0.5, 1)
