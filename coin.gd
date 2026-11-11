class_name Coin
extends Node2D

signal collected(amount: int)
@export var value := 5
@export var magnet_speed := 260.0
@export var lifetime := 25.0
@export var pickup_distance := 30.0

var caravan: Caravan = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	caravan = get_tree().get_first_node_in_group("caravan") as Caravan # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
		
	if caravan == null:
		return
		
	var distance := global_position.distance_to(caravan.global_position)
	
	if distance <= caravan.get_light_radius():
		global_position = global_position.move_toward(caravan.global_position, magnet_speed * delta)
		
		if distance <= pickup_distance:
			collected.emit(value)
			queue_free()
