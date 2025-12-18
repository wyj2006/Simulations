class_name Sand extends RigidBody3D

var stable = false
var last_position

func _physics_process(_delta: float) -> void:
	if last_position == position:
		stable = true
	last_position = position
	if position.y < 0:
		get_parent().remove_child(self)