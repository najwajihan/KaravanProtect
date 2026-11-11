class_name Caravan
extends Node2D

# Sinyal: karavan "berteriak" saat sampai tujuan atau hancur. Main yang mendengarkan.
signal arrived
signal destroyed

@export var speed := 40.0               # naikkan ke 150 kalau mau tes cepat
@export var destination_x := 3000.0
@export var max_oil := 100.0
@export var max_hp := 200.0
@export var drain_rate := 4.0           # minyak berkurang per detik saat karavan jalan
@export var fill_rate := 30.0           # minyak bertambah per detik saat dituang
@export var min_light_radius := 70.0    # radius cahaya saat minyak habis
@export var max_light_radius := 280.0   # radius cahaya saat minyak penuh

var oil := 100.0
var hp := 200.0
var has_arrived := false

func _ready():
	oil = max_oil
	hp = max_hp
	add_to_group("caravan")

func _process(delta):
	if not has_arrived and hp > 0.0:
		position.x = move_toward(position.x, destination_x, speed * delta)
		oil = maxf(oil - drain_rate * delta, 0.0)
		if is_equal_approx(position.x, destination_x):
			has_arrived = true
			arrived.emit()
	queue_redraw()

func add_oil(delta):
	oil = minf(oil + fill_rate * delta, max_oil)

# Dipanggil oleh musuh saat menyerang karavan
func take_damage(amount: float):
	# Setelah sampai tujuan karavan kebal, jadi "menang" tidak bisa berubah jadi "kalah"
	if hp <= 0.0 or has_arrived:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		destroyed.emit()

func get_light_radius() -> float:
	return lerpf(min_light_radius, max_light_radius, oil / max_oil)

func _draw():
	var radius := get_light_radius()
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.85, 0.4, 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, 0.8), 2.0)
