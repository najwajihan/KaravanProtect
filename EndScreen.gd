extends Control

func _ready():
	$RestartButton.pressed.connect(_restart)

func _process(_delta):
	# Tombol R juga bisa dipakai untuk restart
	if Input.is_action_just_pressed("restart"):
		_restart()

func _restart():
	get_tree().change_scene_to_file("res://main.tscn")
