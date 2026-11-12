extends Node2D

enum Mode { GUARD, LANTERN }

const ENEMY_SCENE = preload("res://enemy.tscn")
const COIN_SCENE = preload("res://coin.tscn")
const CARD_SCENE = preload("res://card.tscn")

@export var start_coins := 30
@export var spawn_distance := 700.0
@export var max_enemies := 60
@export var min_spawn_interval := 0.6
@export var spawn_speedup := 0.02
# Checkpoint di 25%, 50%, 75% perjalanan
@export var checkpoint_fractions: Array[float] = [0.25, 0.5, 0.75]
@export var choices_per_checkpoint := 3
@export var strengthen_bonus := 0.25   # hadiah Perkuat: +25% HP dan damage
@export var speed_bonus := 10.0        # hadiah Roda: +10 kecepatan karavan

# Data kartu peran baru. Menambah peran baru = menambah satu blok di sini.
var role_data := {
	"shield": {
		"name": "Tameng",
		"scene": preload("res://shield_guard.tscn"),
		"cost": 3,
		"cooldown": 1.5,
		"color": Color(0.85, 0.65, 0.13),
		"ghost": Color(0.85, 0.65, 0.13, 0.6),
		"desc": "Pengawal tebal tapi lambat. Bagus untuk menahan musuh."
	},
	"scout": {
		"name": "Pengintai",
		"scene": preload("res://scout_guard.tscn"),
		"cost": 2,
		"cooldown": 0.8,
		"color": Color(0.37, 0.88, 0.54),
		"ghost": Color(0.37, 0.88, 0.54, 0.6),
		"desc": "Pengawal rapuh tapi cepat dan sering memukul."
	}
}

var current_mode: Mode = Mode.GUARD
var coins := 0
var game_over := false
var message_time_left := 0.0
var start_x := 0.0
var total_distance := 1.0
var next_checkpoint := 0
var unlocked_roles: Array[String] = []

@onready var caravan: Caravan = $Caravan
@onready var units: Node2D = $Units
@onready var enemy_timer: Timer = $EnemyTimer
@onready var card_row: VBoxContainer = $HUD/CardRow
@onready var oil_bar = $HUD/OilBar
@onready var travel_bar = $HUD/TravelBar
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var coin_label: Label = $HUD/CoinLabel
@onready var mode_label: Label = $HUD/ModeLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var checkpoint_panel: Control = $HUD/CheckpointPanel
@onready var choices_box: HBoxContainer = $HUD/CheckpointPanel/Choices

func _ready():
	get_tree().paused = false
	coins = start_coins
	for card in _all_cards():
		card.dropped.connect(_on_card_dropped)
	caravan.arrived.connect(_on_caravan_arrived)
	caravan.destroyed.connect(_on_caravan_destroyed)
	enemy_timer.timeout.connect(_spawn_enemy)
	oil_bar.max_value = caravan.max_oil
	hp_bar.max_value = caravan.max_hp
	start_x = caravan.position.x
	total_distance = maxf(caravan.destination_x - start_x, 1.0)
	travel_bar.max_value = total_distance
	_build_checkpoint_ticks()
	checkpoint_panel.hide()
	message_label.text = ""
	_apply_mode()

func _process(delta):
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	if game_over:
		return

	if message_time_left > 0.0:
		message_time_left -= delta
		if message_time_left <= 0.0:
			message_label.text = ""

	if Input.is_action_just_pressed("switch_role"):
		if current_mode == Mode.GUARD:
			current_mode = Mode.LANTERN
		else:
			current_mode = Mode.GUARD
		_apply_mode()

	if current_mode == Mode.LANTERN and Input.is_action_pressed("pour_oil"):
		caravan.add_oil(delta)

	for card in _all_cards():
		card.affordable = coins >= card.cost
	oil_bar.set_value(caravan.oil)
	hp_bar.value = caravan.hp
	coin_label.text = "Koin: " + str(coins)
	travel_bar.set_value(caravan.position.x - start_x)
	_check_checkpoint()

func _all_cards() -> Array[Card]:
	var result: Array[Card] = []
	for child in card_row.get_children():
		if child is Card:
			result.append(child)
	return result

func _apply_mode():
	var is_guard := current_mode == Mode.GUARD
	if is_guard:
		mode_label.text = "Peran: PENGAWAL (tarik kartu) | E untuk ganti"
	else:
		mode_label.text = "Peran: PENJAGA LENTERA (tahan Spasi) | E untuk ganti"
	for card in _all_cards():
		card.enabled = is_guard

func _show_message(text: String):
	message_label.text = text
	message_time_left = 1.5

# ---------- Musuh dan koin (koin hanya dari musuh) ----------

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

func _on_card_dropped(card: Card):
	if game_over:
		return
	var spawn_pos := get_global_mouse_position()
	if spawn_pos.distance_to(caravan.global_position) > caravan.get_light_radius():
		_show_message("Di luar cahaya!")
		return
	if coins < card.cost:
		_show_message("Koin tidak cukup")
		return
	coins -= card.cost
	var guard := card.guard_scene.instantiate() as Guard
	# Atur kekuatan SEBELUM add_child, karena Guard mengisi hp di _ready
	guard.max_hp *= card.hp_mult
	guard.attack_damage *= card.damage_mult
	units.add_child(guard)
	guard.global_position = spawn_pos
	card.start_cooldown()

# ---------- Progress dan checkpoint ----------

func _build_checkpoint_ticks():
	for fraction in checkpoint_fractions:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1)
		tick.size = Vector2(4, 24)
		tick.position = Vector2(travel_bar.bar_width * fraction - 2.0, 0.0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		travel_bar.add_child(tick)
		travel_bar.move_child(tick, 2)   # di atas Track dan Fill, di bawah Marker

func _check_checkpoint():
	if next_checkpoint >= checkpoint_fractions.size():
		return
	var progress := (caravan.position.x - start_x) / total_distance
	if progress >= checkpoint_fractions[next_checkpoint]:
		next_checkpoint += 1
		_open_checkpoint()

func _open_checkpoint():
	var options := _roll_options()
	get_tree().paused = true
	for card in _all_cards():
		card.enabled = false
	for option in options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 200)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = option["title"] + "\n\n" + option["desc"]
		button.pressed.connect(_on_option_chosen.bind(option))
		choices_box.add_child(button)
	checkpoint_panel.show()

func _roll_options() -> Array:
	var pool: Array = []
	# 1) Kartu peran baru yang belum diambil
	for role_id in role_data:
		if not unlocked_roles.has(role_id):
			var data: Dictionary = role_data[role_id]
			pool.append({"kind": "new_card", "id": role_id,
				"title": "KARTU BARU: " + data["name"], "desc": data["desc"]})
	# 2) Perkuat setiap kartu yang sudah dimiliki
	for card in _all_cards():
		pool.append({"kind": "strengthen", "card": card,
			"title": "PERKUAT: " + card.card_name,
			"desc": "HP dan damage pengawal kartu ini +" + str(int(strengthen_bonus * 100)) + "%."})
	# 3) Karavan lebih cepat
	pool.append({"kind": "speed", "title": "RODA LEBIH CEPAT",
		"desc": "Kecepatan karavan +" + str(int(speed_bonus)) + ". Sampai tujuan lebih cepat."})
	pool.shuffle()
	return pool.slice(0, mini(choices_per_checkpoint, pool.size()))

func _on_option_chosen(option: Dictionary):
	_apply_option(option)
	for child in choices_box.get_children():
		child.queue_free()
	checkpoint_panel.hide()
	get_tree().paused = false
	_apply_mode()

func _apply_option(option: Dictionary):
	match option["kind"]:
		"new_card":
			_unlock_role(option["id"])
		"strengthen":
			var card: Card = option["card"]
			card.level += 1
			card.hp_mult += strengthen_bonus
			card.damage_mult += strengthen_bonus
			card.refresh_labels()
		"speed":
			caravan.speed += speed_bonus
	_show_message(option["title"])

func _unlock_role(role_id: String):
	unlocked_roles.append(role_id)
	var data: Dictionary = role_data[role_id]
	var card := CARD_SCENE.instantiate() as Card
	card.card_name = data["name"]
	card.guard_scene = data["scene"]
	card.cost = data["cost"]
	card.cooldown_time = data["cooldown"]
	card.card_color = data["color"]
	card.ghost_color = data["ghost"]
	card_row.add_child(card)     # HBoxContainer menaruhnya di samping kartu lama
	card.dropped.connect(_on_card_dropped)

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
