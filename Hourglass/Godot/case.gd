class_name Case extends StaticBody3D

@export var bottom_radius = 50.0
@export var top_radius = 100.0
@export var height = 100.0
@export var point_num = 100

func _ready() -> void:
	for i in range(point_num + 1):
		var angle = i * 2 * PI / point_num
		for k in [1, -1]:
			var points = []

			match k:
				1:
					points.append(Vector3(bottom_radius * sin(angle), 0, bottom_radius * cos(angle)))
					points.append(Vector3(top_radius * sin(angle), height, top_radius * cos(angle)))
					angle = (i + k) * 2 * PI / point_num
					points.append(Vector3(bottom_radius * sin(angle), 0, bottom_radius * cos(angle)))
				-1:
					points.append(Vector3(bottom_radius * sin(angle), 0, bottom_radius * cos(angle)))
					points.append(Vector3(top_radius * sin(angle), height, top_radius * cos(angle)))
					angle = (i + k) * 2 * PI / point_num
					points.append(Vector3(top_radius * sin(angle), height, top_radius * cos(angle)))

			var shape = ConvexPolygonShape3D.new()
			shape.points = points
			var collision = CollisionShape3D.new()
			collision.shape = shape
			add_child(collision)