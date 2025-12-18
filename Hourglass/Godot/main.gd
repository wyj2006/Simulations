extends Node3D

@onready var case: Case = $Case
@onready var board = $Board

var SandScene = preload("res://sand.tscn")
var time = 0

func _ready() -> void:
	$Board/CollisionShape3D.shape.size = Vector3(case.bottom_radius, 1, case.bottom_radius) * 2
	for i in range(10000):
		var sand = SandScene.instantiate()
		sand.position = Vector3(randf_range(-case.top_radius / 2, case.top_radius / 2), randf_range(case.height, case.height * 2), randf_range(-case.top_radius / 2, case.top_radius / 2))
		add_child(sand)

func _on_timer_timeout() -> void:
	var sands = []
	for child in get_children():
		if child is Sand:
			sands.append(child)
			if not child.stable:
				return
	time += 1
	$%Label.text = var_to_str(time * $Timer.wait_time)
	if len(sands) == 0:
		$Timer.stop()

func _on_button_pressed() -> void:
	remove_child(board)
	$%Button.hide()
