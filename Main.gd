extends Node2D

enum Mode { GUARD, LANTERN }

const GUARD_SCENE = preload("res://guard.tscn")
const ENEMY_SCENE = preload("res://enemy.tscn")
const COIN_SCENE = preload("res://coin.tscn")

@export var start_coins := 30
@export var spawn_distance := 700.0     # musuh muncul sejauh ini dari karavan (di luar layar)
@export var max_enemies := 60
@export var min_spawn_interval := 0.6   # jeda spawn tercepat (detik)
@export var spawn_speedup := 0.02       # setiap spawn, jeda dipercepat sebesar ini

var current_mode: Mode = Mode.GUARD
var coins := 0
var game_over := false
var message_time_left := 0.0

@onready var caravan: Caravan = $Caravan
@onready var units: Node2D = $Units
@onready var enemy_timer: Timer = $EnemyTimer
@onready var card = $HUD/Card
@onready var oil_bar = $HUD/OilBar
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var coin_label: Label = $HUD/CoinLabel
@onready var mode_label: Label = $HUD/ModeLabel
@onready var message_label: Label = $HUD/MessageLabel

func _ready():
	coins = start_coins
	card.dropped.connect(_on_card_dropped)
	caravan.arrived.connect(_on_caravan_arrived)
	caravan.destroyed.connect(_on_caravan_destroyed)
	enemy_timer.timeout.connect(_spawn_enemy)
	oil_bar.max_value = caravan.max_oil
	hp_bar.max_value = caravan.max_hp
	message_label.text = ""
	_apply_mode()

func _process(delta):
	# Tombol R: mulai ulang (berguna saat menguji)
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	if game_over:
		return

	if message_time_left > 0.0:
		message_time_left -= delta
		if message_time_left <= 0.0:
			message_label.text = ""

	# Pergantian peran manual: tekan E untuk bolak-balik
	if Input.is_action_just_pressed("switch_role"):
		if current_mode == Mode.GUARD:
			current_mode = Mode.LANTERN
		else:
			current_mode = Mode.GUARD
		_apply_mode()

	# Menuang minyak hanya bisa saat berada di peran penjaga lentera
	if current_mode == Mode.LANTERN and Input.is_action_pressed("pour_oil"):
		caravan.add_oil(delta)

	# Perbarui tampilan antarmuka
	card.affordable = coins >= card.cost
	oil_bar.set_value(caravan.oil)
	hp_bar.value = caravan.hp
	coin_label.text = "Koin: " + str(coins)

func _apply_mode():
	if current_mode == Mode.GUARD:
		mode_label.text = "Peran: PENGAWAL (tarik kartu) | E untuk ganti"
		card.enabled = true
	else:
		mode_label.text = "Peran: PENJAGA LENTERA (tahan Spasi) | E untuk ganti"
		card.enabled = false

func _show_message(text: String):
	message_label.text = text
	message_time_left = 1.5

# ---------- Musuh dan koin ----------

func _spawn_enemy():
	if game_over:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	var angle := randf() * TAU
	var spawn_pos := caravan.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	units.add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.died.connect(_on_enemy_died)
	enemy_timer.wait_time = maxf(min_spawn_interval, enemy_timer.wait_time - spawn_speedup)

func _on_enemy_died(world_position: Vector2, coin_value: int):
	var coin := COIN_SCENE.instantiate() as Coin
	coin.value = coin_value
	units.add_child(coin)
	coin.global_position = world_position
	coin.collected.connect(_on_coin_collected)

func _on_coin_collected(amount: int):
	coins += amount

# ---------- Kartu ----------

func _on_card_dropped():
	if game_over:
		return
	var spawn_pos := get_global_mouse_position()
	var distance := spawn_pos.distance_to(caravan.global_position)
	if distance > caravan.get_light_radius():
		_show_message("Di luar cahaya!")
		return
	if coins < card.cost:
		_show_message("Koin tidak cukup")
		return
	coins -= card.cost
	var guard := GUARD_SCENE.instantiate() as Guard
	units.add_child(guard)
	guard.global_position = spawn_pos
	card.start_cooldown()

# ---------- Menang dan kalah ----------

func _on_caravan_arrived():
	if game_over:
		return
	game_over = true
	enemy_timer.stop()
	get_tree().change_scene_to_file("res://WinScreen.tscn")

func _on_caravan_destroyed():
	if game_over:
		return
	game_over = true
	enemy_timer.stop()
	get_tree().change_scene_to_file("res://game_over_screen.tscn")
