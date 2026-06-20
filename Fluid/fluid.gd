extends MultiMeshInstance2D

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
## 只用于设置颜色, 不会影响实际速度
@export var max_speed = 100.0
var target_density

@onready var border_left_up = Vector2(-width / 2, -height / 2)
@onready var border_right_up = Vector2(width / 2, -height / 2)
@onready var border_left_down = Vector2(-width / 2, height / 2)
@onready var border_right_down = Vector2(width / 2, height / 2)
@onready var group_count = ceil(particle_num / 256.0)

var dt = 1.0 / 120
var spatial_lookup: Array[Vector2i]
var start_indices: PackedInt32Array

var rd: RenderingDevice
var compute_shaders: Array[RID]
var gpu_buffers: Array[RID]
var uniform_set: RID
var compute_pipelines = []

var lookup_shaders: Array[RID]
var lookup_pipelines = []

var radix_bits := 8
var radix_shift := 0
var radix_count: PackedInt32Array
var radix_offset: PackedInt32Array
var radix_temp: Array[Vector2i]
var radix_sort_shaders: Array[RID]
var radix_sort_pipelines = []

func w_poly6(dest: float, radius: float) -> float:
    if dest > radius:
        return 0
    var k_poly6 = 4 / (PI * pow(radius, 8))
    return k_poly6 * pow(radius * radius - dest * dest, 3)

func create_buffer(data: PackedByteArray) -> RID:
    var buffer := rd.storage_buffer_create(data.size(), data)
    assert(buffer.is_valid())
    return buffer

func update_buffer(buffer, data: PackedByteArray):
    rd.buffer_update(buffer, 0, data.size(), data)

func vec2i_to_int32_array(a: Array) -> PackedInt32Array:
    var result = PackedInt32Array()
    result.resize(a.size() * 2)
    for i in range(a.size()):
        result[i * 2] = a[i].x
        result[i * 2 + 1] = a[i].y
    return result

func get_shader(file):
    var shader_file := load(file)
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
    var shader = rd.shader_create_from_spirv(shader_spirv)
    assert(shader.is_valid())
    return shader

func get_params_array():
    return PackedFloat32Array([
        float(particle_num),
        smooth_radius,
        mass,
        gravity,
        width,
        height,
        pressure_multiplier,
        viscosity,
        target_density,
        particle_radius,
        collision_damp,
        dt,
        float(radix_bits),
        float(radix_shift)
    ])

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
    particle_densities.fill(0)

    spatial_lookup.resize(particle_num)
    start_indices.resize(particle_num)

    multimesh.instance_count = particle_num
    multimesh.mesh.radius = particle_radius
    multimesh.mesh.height = particle_radius * 2

    radix_count.resize(1 << radix_bits)
    radix_temp.resize(particle_num)
    radix_offset.resize(particle_num)

    rd = RenderingServer.create_local_rendering_device()

    lookup_shaders.push_back(get_shader("res://build_lookup_map.glsl"))
    lookup_shaders.push_back(get_shader("res://build_lookup_indices.glsl"))

    for shader in lookup_shaders:
        var pipeline = rd.compute_pipeline_create(shader)
        assert(pipeline.is_valid())
        lookup_pipelines.push_back(pipeline)

    compute_shaders.push_back(get_shader("res://compute_density.glsl"))
    compute_shaders.push_back(get_shader("res://compute_force.glsl"))
    compute_shaders.push_back(get_shader("res://compute_position.glsl"))

    for shader in compute_shaders:
        var pipeline = rd.compute_pipeline_create(shader)
        assert(pipeline.is_valid())
        compute_pipelines.push_back(pipeline)

    radix_sort_shaders.push_back(get_shader("res://radix_sort_count.glsl"))
    radix_sort_shaders.push_back(get_shader("res://radix_sort_scatter.glsl"))
    radix_sort_shaders.push_back(get_shader("res://radix_sort_swap.glsl"))

    for shader in radix_sort_shaders:
        var pipeline = rd.compute_pipeline_create(shader)
        assert(pipeline.is_valid())
        radix_sort_pipelines.push_back(pipeline)

    gpu_buffers = [
        create_buffer(get_params_array().to_byte_array()),
        create_buffer(particle_positions.to_byte_array()),
        create_buffer(particle_velocities.to_byte_array()),
        create_buffer(particle_densities.to_byte_array()),
        create_buffer(particle_external_forces.to_byte_array()),
        create_buffer(vec2i_to_int32_array(spatial_lookup).to_byte_array()),
        create_buffer(start_indices.to_byte_array()),
        create_buffer(radix_count.to_byte_array()),
        create_buffer(vec2i_to_int32_array(radix_temp).to_byte_array()),
        create_buffer(radix_offset.to_byte_array())
    ]

    var uniforms: Array[RDUniform] = []
    for i in range(gpu_buffers.size()):
        var uniform := RDUniform.new()
        uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
        uniform.binding = i
        uniform.add_id(gpu_buffers[i])
        uniforms.append(uniform)
    uniform_set = rd.uniform_set_create(uniforms, lookup_shaders[0], 0)
    assert(uniform_set.is_valid())

func _process(delta: float) -> void:
    dt = delta
    
    step()

    for i in range(particle_num):
        multimesh.set_instance_transform_2d(i, Transform2D(0, particle_positions[i]))
        multimesh.set_instance_color(i, particle_gradient.sample(clamp(particle_velocities[i].length() / max_speed, 0, 1)))

func _draw() -> void:
    draw_polyline([border_left_up, border_right_up, border_right_down, border_left_down, border_left_up], Color.BLACK)

func step():
    update_buffer(gpu_buffers[4], particle_external_forces.to_byte_array())
    
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, lookup_pipelines[0])
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, group_count, 1, 1)
    rd.compute_list_end()
    rd.submit()
    rd.sync()

    radix_shift = 0
    @warning_ignore("integer_division")
    for _i in range(32 / radix_bits):
        radix_count.fill(0)
        update_buffer(gpu_buffers[7], radix_count.to_byte_array())
        update_buffer(gpu_buffers[0], get_params_array().to_byte_array())

        compute_list = rd.compute_list_begin()

        rd.compute_list_bind_compute_pipeline(compute_list, radix_sort_pipelines[0])
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_dispatch(compute_list, group_count, 1, 1)

        rd.compute_list_end()

        rd.submit()
        rd.sync()

        #求前缀和
        radix_count = rd.buffer_get_data(gpu_buffers[7]).to_int32_array()
        for i in range(1, radix_count.size()):
            radix_count[i] += radix_count[i - 1]
        #起始位置
        for i in range(radix_count.size() - 1, 0, -1):
            radix_count[i] = radix_count[i - 1]
        radix_count[0] = 0
        update_buffer(gpu_buffers[7], radix_count.to_byte_array())

        compute_list = rd.compute_list_begin()

        rd.compute_list_bind_compute_pipeline(compute_list, radix_sort_pipelines[1])
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_dispatch(compute_list, group_count, 1, 1)
        rd.compute_list_add_barrier(compute_list)

        rd.compute_list_bind_compute_pipeline(compute_list, radix_sort_pipelines[2])
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_dispatch(compute_list, group_count, 1, 1)

        rd.compute_list_end()

        rd.submit()
        rd.sync()

        radix_shift += radix_bits

    compute_list = rd.compute_list_begin()
    
    rd.compute_list_bind_compute_pipeline(compute_list, lookup_pipelines[1])
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, group_count, 1, 1)
    rd.compute_list_add_barrier(compute_list)

    for pipeline in compute_pipelines:
        rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_dispatch(compute_list, group_count, 1, 1)
        rd.compute_list_add_barrier(compute_list)

    rd.compute_list_end()

    rd.submit()
    rd.sync()

    particle_positions = rd.buffer_get_data(gpu_buffers[1]).to_vector2_array()
    particle_velocities = rd.buffer_get_data(gpu_buffers[2]).to_vector2_array()
