extends Camera3D

@export var move_speed = 0.05
@export var rotate_speed = 0.05

var control = true

func _process(_delta: float) -> void:
	if not control:
		return
	var direction = Vector3(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"), Input.get_action_strength("move_up") - Input.get_action_strength("move_down"), Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward"))
	direction = direction.rotated(Vector3.UP, rotation.y)
	direction = direction.normalized()
	position += direction * move_speed
	if Input.is_action_just_pressed("ui_cancel"):
		control = not control

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and control:
		var center = round(get_viewport().get_visible_rect().size / 2)
		var dpos = event.position - center
		rotation += Vector3(-deg_to_rad(dpos.y), -deg_to_rad(dpos.x), 0).normalized() * rotate_speed
		Input.warp_mouse(center)
