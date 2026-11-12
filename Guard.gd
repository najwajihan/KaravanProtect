class_name Guard
extends Node2D

@export var max_hp := 40.0
@export var move_speed := 100.0          # kecepatan saat mengejar musuh / kembali ke cahaya
@export var attack_damage := 8.0
@export var attack_range := 30.0         # jarak serang (piksel)
@export var attack_cooldown := 0.8       # jeda antar serangan (detik)
@export var detect_range := 260.0        # seberapa jauh pengawal melihat musuh
@export var engage_margin := 60.0        # musuh dilawan kalau berada di dalam cahaya + jarak ini
@export var wander_speed := 50.0         # kecepatan jalan santai saat berkeliling
@export var wander_pause_max := 1.5      # lama berhenti maksimum di tiap titik (detik)
@export var edge_margin := 25.0          # pengawal menjauh dari tepi cahaya sejauh ini
@export var keep_out_radius := 90.0      # pengawal tidak boleh lebih dekat dari ini ke pusat karavan
@export var hp_bar_width := 24.0

var hp := 0.0
var time_since_attack := 0.0
var caravan: Caravan = null
var last_caravan_pos := Vector2.ZERO
var wander_offset := Vector2.ZERO        # titik tujuan, relatif terhadap karavan
var wander_wait := 0.0
var wander_timer := 0.0

@onready var hp_fill: ColorRect = $HpFill

func _ready():
	hp = max_hp
	add_to_group("guards")
	caravan = get_tree().get_first_node_in_group("caravan") as Caravan
	if caravan != null:
		last_caravan_pos = caravan.global_position
	_update_hp_bar()

func _process(delta):
	time_since_attack += delta
	if caravan == null:
		return
	var caravan_move := caravan.global_position - last_caravan_pos
	last_caravan_pos = caravan.global_position

	var target := _find_nearest_enemy()
	if target != null:
		_fight(target, delta)
	else:
		_wander(delta, caravan_move)
	# Selalu dijalankan terakhir: pengawal tidak boleh masuk ke karavan
	_keep_out_of_caravan()

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := detect_range
	var engage_radius := caravan.get_light_radius() + engage_margin
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(caravan.global_position) > engage_radius:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _fight(target: Node2D, delta: float):
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range:
		global_position += global_position.direction_to(target.global_position) * move_speed * delta
	elif time_since_attack >= attack_cooldown:
		time_since_attack = 0.0
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

# Batas terluar area berkeliling. Tidak pernah lebih kecil dari zona terlarang + 15,
# jadi saat cahaya menyusut pengawal berjaga tepat di luar karavan.
func _wander_limit() -> float:
	return maxf(caravan.get_light_radius() - edge_margin, keep_out_radius + 15.0)

func _wander(delta: float, caravan_move: Vector2):
	# Ikut terbawa gerak karavan supaya tidak tertinggal
	global_position += caravan_move

	var center := caravan.global_position
	var limit := _wander_limit()

	# Kalau di luar area berkeliling (misalnya cahaya menyusut), masuk lagi dulu
	if global_position.distance_to(center) > limit:
		global_position = global_position.move_toward(center, move_speed * delta)
		return

	if wander_wait > 0.0:
		wander_wait -= delta
		return

	if wander_offset == Vector2.ZERO:
		_pick_wander_point()

	# Tujuan dijaga tetap di dalam cincin (di luar zona terlarang, di dalam cahaya)
	var inner := keep_out_radius + 10.0
	var ring_length := clampf(wander_offset.length(), inner, maxf(limit, inner))
	var goal := center + Vector2.RIGHT.rotated(wander_offset.angle()) * ring_length

	wander_timer += delta
	if global_position.distance_to(goal) < 4.0 or wander_timer > 6.0:
		wander_wait = randf_range(0.3, wander_pause_max)
		_pick_wander_point()
	else:
		global_position = global_position.move_toward(goal, wander_speed * delta)

func _pick_wander_point():
	wander_timer = 0.0
	var inner := keep_out_radius + 10.0
	var outer := maxf(_wander_limit(), inner)
	# Coba beberapa titik, ambil yang jalurnya tidak menembus karavan
	for i in 8:
		wander_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(inner, outer)
		if not _path_blocked(caravan.global_position + wander_offset):
			return

func _path_blocked(goal: Vector2) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(
		caravan.global_position, global_position, goal)
	return closest.distance_to(caravan.global_position) < keep_out_radius - 1.0

func _keep_out_of_caravan():
	var offset := global_position - caravan.global_position
	if offset.length() < keep_out_radius:
		if offset.length() < 0.01:
			offset = Vector2.RIGHT
		global_position = caravan.global_position + offset.normalized() * keep_out_radius

func take_damage(amount: float):
	if is_queued_for_deletion():
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		queue_free()

func _update_hp_bar():
	hp_fill.size.x = hp_bar_width * clampf(hp / max_hp, 0.0, 1.0)
