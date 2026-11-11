class_name Guard
extends Node2D

@export var max_hp := 40.0
@export var move_speed := 100.0
@export var attack_damage := 8.0
@export var attack_range := 30.0        # jarak serang (piksel)
@export var attack_cooldown := 0.8    # jeda antar serangan (detik)
@export var detect_range := 260.0       # seberapa jauh pengawal melihat musuh
@export var leash_radius := 420.0       # pengawal tidak mengejar musuh yang terlalu jauh dari karavan
@export var follow_radius := 200.0      # kalau tidak ada musuh, pengawal tetap dekat karavan
@export var hp_bar_width := 24.0

var hp := 0.0
var time_since_attack := 0.0
var caravan: Node2D = null

@onready var hp_fill: ColorRect = $HpFill

func _ready():
	hp = max_hp
	add_to_group("guards")
	caravan = get_tree().get_first_node_in_group("caravan") as Node2D
	_update_hp_bar()

func _process(delta):
	time_since_attack += delta
	var target := _find_nearest_enemy()
	if target != null:
		_fight(target, delta)
	else:
		_return_to_caravan(delta)

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := detect_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		# Abaikan musuh yang terlalu jauh dari karavan
		if caravan != null and enemy.global_position.distance_to(caravan.global_position) > leash_radius:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _fight(target: Node2D, delta: float):
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range:
		# Masih jauh: berjalan mendekat
		global_position += global_position.direction_to(target.global_position) * move_speed * delta
	elif time_since_attack >= attack_cooldown:
		# Sudah dekat dan serangan siap: pukul
		time_since_attack = 0.0
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func _return_to_caravan(delta: float):
	if caravan == null:
		return
	var distance := global_position.distance_to(caravan.global_position)
	if distance > follow_radius:
		global_position += global_position.direction_to(caravan.global_position) * move_speed * delta

func take_damage(amount: float):
	if is_queued_for_deletion():
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		queue_free()   # pengawal gugur

func _update_hp_bar():
	hp_fill.size.x = hp_bar_width * clampf(hp / max_hp, 0.0, 1.0)
