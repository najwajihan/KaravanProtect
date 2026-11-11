class_name Enemy
extends Node2D

# Dipancarkan saat musuh mati, supaya Main bisa menjatuhkan koin
signal died(world_position: Vector2, coin_value: int)

@export var max_hp := 30.0
@export var move_speed := 60.0
@export var attack_damage := 6.0
@export var attack_range := 30.0           # jarak serang ke pengawal
@export var caravan_attack_range := 80.0   # karavan besar, jadi jarak seranginya lebih jauh
@export var attack_cooldown := 1.0
@export var aggro_range := 140.0           # musuh mengejar pengawal yang lebih dekat dari ini
@export var coin_value := 5
@export var hp_bar_width := 24.0

var hp := 0.0
var time_since_attack := 0.0
var caravan: Node2D = null

@onready var hp_fill: ColorRect = $HpFill

func _ready():
	hp = max_hp
	add_to_group("enemies")
	caravan = get_tree().get_first_node_in_group("caravan") as Node2D
	_update_hp_bar()

func _process(delta):
	time_since_attack += delta
	var guard := _find_nearest_guard()
	if guard != null:
		# Ada pengawal di dekat: lawan pengawal dulu
		_chase_or_attack(guard, attack_range, delta)
	elif caravan != null:
		# Tidak ada pengawal: serang karavan
		_chase_or_attack(caravan, caravan_attack_range, delta)

func _find_nearest_guard() -> Node2D:
	var best: Node2D = null
	var best_distance := aggro_range
	for node in get_tree().get_nodes_in_group("guards"):
		var guard := node as Node2D
		if guard == null or guard.is_queued_for_deletion():
			continue
		var distance := global_position.distance_to(guard.global_position)
		if distance < best_distance:
			best_distance = distance
			best = guard
	return best

func _chase_or_attack(target: Node2D, reach: float, delta: float):
	var distance := global_position.distance_to(target.global_position)
	if distance > reach:
		global_position += global_position.direction_to(target.global_position) * move_speed * delta
	elif time_since_attack >= attack_cooldown:
		time_since_attack = 0.0
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func take_damage(amount: float):
	if is_queued_for_deletion():
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		died.emit(global_position, coin_value)
		queue_free()

func _update_hp_bar():
	hp_fill.size.x = hp_bar_width * clampf(hp / max_hp, 0.0, 1.0)
