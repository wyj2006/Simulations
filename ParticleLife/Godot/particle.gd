class_name Particle extends RigidBody2D

@export var color := Color.RED

@onready var world: World = get_node("/root/World")

##位于最大作用区域以内的粒子
var interact_particles: Array[Particle] = []
##位于最小作用区域以内的例子
var exclued_particles: Array[Particle] = []

var radius:
    get:
        return $CollisionShape2D.shape.radius

func _draw() -> void:
    draw_circle(Vector2i(0, 0), radius, color)

func _on_max_interact_area_body_entered(body: Node2D) -> void:
    if body is not Particle or body == self:
        return
    interact_particles.append(body)

func _on_max_interact_area_body_exited(body: Node2D) -> void:
    if body is not Particle or body == self:
        return
    interact_particles.erase(body)

func _on_min_interact_area_body_entered(body: Node2D) -> void:
    if body is not Particle or body == self:
        return
    exclued_particles.append(body)

func _on_min_interact_area_body_exited(body: Node2D) -> void:
    if body is not Particle or body == self:
        return
    exclued_particles.erase(body)

func _physics_process(_delta: float) -> void:
    for particle in interact_particles:
        if particle in exclued_particles:
            continue
        var direction = (particle.position - position).normalized()
        particle.apply_force(direction * world.interact_forces[[color, particle.color]])
