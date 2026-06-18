extends Node2D

@export var width = 50.0
@export var height = 50.0

@export var particle_num = 100
@export var particle_radius = 1.0
@export var particle_gradient: Gradient
@export var particle_spacing = 1.0
var particle_positions: PackedVector2Array
var particle_velocities: PackedVector2Array
var particle_densities: PackedFloat32Array
var particle_external_forces: PackedVector2Array

@export var gravity = 9.8
@export var collision_damp = 0.05
@export var mass = 1.0
@export var smooth_radius = 10.0
@export var pressure_multiplier = 5000.0
@export var viscosity = 10.0
var target_density

@onready var border_left_up = Vector2(-width / 2, -height / 2)
@onready var border_right_up = Vector2(width / 2, -height / 2)
@onready var border_left_down = Vector2(-width / 2, height / 2)
@onready var border_right_down = Vector2(width / 2, height / 2)

var dt = 1.0
var spatial_lookup: Array[Vector2i]
var start_indices: Array[int]

func _ready() -> void:
    particle_external_forces.resize(particle_num)
    particle_external_forces.fill(Vector2.ZERO)

    particle_positions.resize(particle_num)

    var particle_per_row = int(sqrt(particle_num))
    @warning_ignore("integer_division")
    var particle_per_col = (particle_num - 1) / particle_per_row + 1
    var spacing = particle_radius * 2 + particle_spacing
    for i in range(particle_positions.size()):
        @warning_ignore("integer_division")
        var x = (i % particle_per_row - particle_per_row / 2) * spacing
        @warning_ignore("integer_division")
        var y = (i / particle_per_row - particle_per_col / 2) * spacing
        particle_positions[i] = Vector2(x, y)

    var x_target_spacing = width / (particle_per_row + 1)
    var y_target_spacing = height / (particle_per_col + 1)
    target_density = w_poly6(0, smooth_radius) \
     +2 * mass * w_poly6(x_target_spacing, smooth_radius) \
     +2 * mass * w_poly6(y_target_spacing, smooth_radius) \
     +4 * mass * w_poly6(sqrt(pow(x_target_spacing, 2) + pow(y_target_spacing, 2)), smooth_radius)

    particle_velocities.resize(particle_num)
    particle_velocities.fill(Vector2.ZERO)

    particle_densities.resize(particle_num)

    spatial_lookup.resize(particle_num)
    start_indices.resize(particle_num)

func _draw() -> void:
    draw_polyline([border_left_up, border_right_up, border_right_down, border_left_down, border_left_up], Color.BLACK)

    var max_speed = particle_velocities[0].length()
    for i in range(1, particle_num):
        max_speed = max(max_speed, particle_velocities[i].length())
    for i in range(particle_num):
        var particle_position = particle_positions[i]
        var speed = particle_velocities[i].length()
        draw_circle(particle_position, particle_radius, particle_gradient.sample(clamp(speed / max_speed, 0, 1)))
        #draw_circle(particle_position, smooth_radius, Color.GRAY, false)

func _process(delta: float) -> void:
    dt = delta
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var mouse_position = get_local_mouse_position()
        for i in enumerate_within_radius(mouse_position):
            particle_external_forces[i] = particle_positions[i] - mouse_position
    else:
        particle_external_forces.fill(Vector2.ZERO)
    step()
    queue_redraw()

func step():
    for i in range(particle_num):
        particle_velocities[i] += Vector2.DOWN * gravity * dt

    update_spatial_lookup()

    for i in range(particle_num):
        particle_densities[i] = calculate_density(particle_positions[i])

    for i in range(particle_num):
        var force = calculate_pressure_force(i) + calculate_viscosity_force(i) + particle_external_forces[i]
        particle_velocities[i] += force / particle_densities[i] * dt

    for i in range(particle_num):
        particle_positions[i] += particle_velocities[i] * dt

        var bound = Vector2(width, height) / 2 - Vector2.ONE * particle_radius

        if abs(particle_positions[i].x) > bound.x:
            particle_positions[i].x = bound.x * (1.0 if particle_positions[i].x >= 0 else -1.0)
            particle_velocities[i].x *= -1 * (1 - collision_damp)
        if abs(particle_positions[i].y) > bound.y:
            particle_positions[i].y = bound.y * (1.0 if particle_positions[i].y >= 0 else -1.0)
            particle_velocities[i].y *= -1 * (1 - collision_damp)

func w_poly6(dest: float, radius: float) -> float:
    if dest > radius:
        return 0
    var k_poly6 = 4 / (PI * pow(radius, 8))
    return k_poly6 * pow(radius * radius - dest * dest, 3)

func grad_w_spiy(dest: Vector2, radius: float) -> Vector2:
    if dest.length() > radius or dest.length() < 1e-6:
        return Vector2.ZERO
    return -dest * 10 / (PI * pow(radius, 5) * dest.length()) * pow(radius - dest.length(), 2)

func laplacian_w_viscosity(dest: float, radius: float) -> float:
    if dest > radius or dest < 1e-6:
        return 0.0
    return 45.0 / (PI * pow(radius, 6)) * (radius - dest)

func calculate_density(sample_point: Vector2) -> float:
    var density = 0
    for i in enumerate_within_radius(sample_point):
        var particle_position = particle_positions[i]
        var dest = sample_point.distance_to(particle_position)
        density += w_poly6(dest, smooth_radius) * mass
    return density

func density_to_pressure(density: float) -> float:
    return (density - target_density) * pressure_multiplier

func calculate_pressure_force(particle_index: int) -> Vector2:
    var force = Vector2.ZERO

    var density0 = particle_densities[particle_index]
    var sample_point = particle_positions[particle_index]

    for i in enumerate_within_radius(sample_point):
        if i == particle_index:
            continue
        var dest = sample_point - particle_positions[i]
        if dest.length() == 0:
            var a = randf_range(0, 2 * PI)
            dest = Vector2(cos(a), sin(a))
        var density = particle_densities[i]
        var shared_pressure = (density_to_pressure(density) + density_to_pressure(density0)) / 2
        force += -shared_pressure * mass / density * grad_w_spiy(dest, smooth_radius)
        
    return force

func calculate_viscosity_force(particle_index: int) -> Vector2:
    var force = Vector2.ZERO

    var velocity0 = particle_velocities[particle_index]
    var sample_point = particle_positions[particle_index]

    for i in enumerate_within_radius(sample_point):
        if i == particle_index:
            continue
        var dest = (sample_point - particle_positions[i]).length()
        var density = particle_densities[i]
        force += viscosity * (particle_velocities[i] - velocity0) * mass / density * laplacian_w_viscosity(dest, smooth_radius)

    return force

func update_spatial_lookup():
    for i in range(particle_num):
        var cell_coord = position_to_cell_coord(particle_positions[i])
        var key = hash(cell_coord) % particle_num
        spatial_lookup[i] = Vector2i(i, key)
        start_indices[i] = 0x0fffffff

    spatial_lookup.sort_custom(func(a, b):
        return a.y < b.y
    )

    for i in range(particle_num):
        var key = spatial_lookup[i].y
        var pre_key = spatial_lookup[i - 1].y if i != 0 else 0xffffffff
        if key != pre_key:
            start_indices[key] = i

func position_to_cell_coord(point: Vector2) -> Vector2i:
    return Vector2i(int(point.x / smooth_radius), int(point.y / smooth_radius))

func enumerate_within_radius(point: Vector2) -> PackedInt32Array:
    var center = position_to_cell_coord(point)
    var indices: PackedInt32Array = []

    for dx in range(-1, 2):
        for dy in range(-1, 2):
            var key = hash(center + Vector2i(dx, dy)) % particle_num
            var start = start_indices[key]
            for i in range(start, particle_num):
                if spatial_lookup[i].y != key:
                    break
                if point.distance_to(particle_positions[spatial_lookup[i].x]) > smooth_radius:
                    continue
                indices.push_back(spatial_lookup[i].x)

    return indices
