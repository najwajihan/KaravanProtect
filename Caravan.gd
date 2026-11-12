class_name Caravan
extends Node2D

signal arrived
signal destroyed

@export var speed := 40.0
@export var destination_x := 3000.0
@export var max_oil := 100.0
@export var max_hp := 200.0
@export var drain_rate := 4.0
@export var fill_rate := 30.0
@export var min_light_radius := 70.0
@export var max_light_radius := 280.0
@export var slow_multiplier := 0.5      # 0.5 = kecepatan jadi separuh saat melambat
@export var slow_duration := 1.5        # lama melambat sejak serangan terakhir (detik)

var oil := 100.0
var hp := 200.0
var has_arrived := false
var slow_time_left := 0.0

@onready var body: ColorRect = $Body

func _ready():
	oil = max_oil
	hp = max_hp
	add_to_group("caravan")

func _process(delta):
	slow_time_left = maxf(slow_time_left - delta, 0.0)
	var is_slowed := slow_time_left > 0.0
	# Karavan memerah sedikit selama melambat, sebagai tanda bagi pemain
	body.modulate = Color(1.0, 0.6, 0.6) if is_slowed else Color(1, 1, 1)

	if not has_arrived and hp > 0.0:
		var speed_factor := slow_multiplier if is_slowed else 1.0
		position.x = move_toward(position.x, destination_x, speed * speed_factor * delta)
		oil = maxf(oil - drain_rate * delta, 0.0)
		if is_equal_approx(position.x, destination_x):
			has_arrived = true
			arrived.emit()
	queue_redraw()

func add_oil(delta):
	oil = minf(oil + fill_rate * delta, max_oil)

func take_damage(amount: float):
	if hp <= 0.0 or has_arrived:
		return
	hp = maxf(hp - amount, 0.0)
	slow_time_left = slow_duration     # baris baru: mulai (atau perpanjang) efek melambat
	if hp <= 0.0:
		destroyed.emit()

func get_light_radius() -> float:
	return lerpf(min_light_radius, max_light_radius, oil / max_oil)

func _draw():
	var radius := get_light_radius()
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.85, 0.4, 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, 0.8), 2.0)
