class_name World extends Node2D

@export var interact_forces: Dictionary = {
    [Color.RED, Color.RED]: 100.0,
    [Color.RED, Color.GREEN]: - 100.0,
    [Color.RED, Color.BLUE]: 100.0,
    [Color.GREEN, Color.GREEN]: - 100.0,
    [Color.GREEN, Color.BLUE]: 100.0,
    [Color.BLUE, Color.BLUE]: - 100.0
}

var ParticleScene = preload("res://particle.tscn")

func _ready() -> void:
    for key in interact_forces:
        var new_key = [key[1], key[0]]
        if new_key in interact_forces:
            continue
        interact_forces[new_key] = interact_forces[key]

    for i in range(1000):
        var particle: Particle = ParticleScene.instantiate()
        particle.color = [Color.RED, Color.GREEN, Color.BLUE][randi_range(0, 2)]
        particle.position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
        add_child(particle)