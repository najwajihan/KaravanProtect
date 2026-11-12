class_name Card
extends ColorRect

signal dropped(card)

@export var card_name := "Pengawal"
@export var guard_scene: PackedScene   # scene pengawal yang dipanggil kartu ini
@export var cooldown_time := 0.5
@export var cost := 1
@export var card_color := Color(0.91, 0.56, 0.62)
@export var ghost_color := Color(0.3, 0.5, 1.0, 0.6)

# Diubah oleh Main saat pemain memilih hadiah "Perkuat"
var level := 1
var hp_mult := 1.0
var damage_mult := 1.0

var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_stop_drag()
		_update_visual()

var affordable := true:
	set(value):
		affordable = value
		_update_visual()

var cooldown_left := 0.0
var is_dragging := false
var ghost: ColorRect = null

@onready var cost_label: Label = $CostLabel
@onready var name_label: Label = $NameLabel

func _ready():
	color = card_color
	refresh_labels()

func refresh_labels():
	cost_label.text = str(cost)
	name_label.text = card_name if level <= 1 else card_name + "\nLv " + str(level)

func _process(delta):
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
		_update_visual()
	if is_dragging and ghost != null:
		ghost.position = get_viewport().get_mouse_position() - ghost.size / 2.0

func can_use() -> bool:
	return enabled and affordable and cooldown_left <= 0.0

func start_cooldown():
	cooldown_left = cooldown_time
	_update_visual()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_use():
			_start_drag()

func _input(event):
	if is_dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_drag()
		dropped.emit(self)

func _start_drag():
	is_dragging = true
	ghost = ColorRect.new()
	ghost.size = Vector2(24, 24)
	ghost.color = ghost_color
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ghost ditaruh di HUD, bukan di CardRow, supaya tidak diatur ulang oleh container
	var hud := find_parent("HUD")
	if hud == null:
		hud = get_parent()
	hud.add_child(ghost)

func _stop_drag():
	is_dragging = false
	if ghost != null:
		ghost.queue_free()
		ghost = null

func _update_visual():
	if can_use():
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(0.5, 0.5, 0.5, 1)
