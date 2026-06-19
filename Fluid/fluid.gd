extends TextureRect

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
@export var pressure_multiplier = 1000.0
@export var viscosity = 10.0
var target_density

@onready var border_left_up = Vector2(-width / 2, -height / 2)
@onready var border_right_up = Vector2(width / 2, -height / 2)
@onready var border_left_down = Vector2(-width / 2, height / 2)
@onready var border_right_down = Vector2(width / 2, height / 2)

var dt = 1.0 / 120
var spatial_lookup: Array[Vector2i]
var start_indices: PackedInt32Array

var rd: RenderingDevice
var compute_shaders: Array[RID]
var gpu_buffers
var uniform_set
var compute_pipelines = []

var render_shader: RID
var render_pipeline: RID
var vertex_buffer: RID
var vertex_array: RID
var framebuffer_texture: RID
var framebuffer: RID

func _ready() -> void:
    size = Vector2(width, height)
    
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

    init_gpu_resources()

func _process(delta: float) -> void:
    dt = delta
    
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var mouse_position = get_local_mouse_position()
        for i in enumerate_within_radius(mouse_position):
            particle_external_forces[i] = particle_positions[i] - mouse_position
    else:
        particle_external_forces.fill(Vector2.ZERO)

    update_spatial_lookup()
    call_gpu()

    var data: PackedByteArray = rd.texture_get_data(framebuffer_texture, 0);
    var image: Image = Image.create_from_data(int(width), int(height), false, Image.FORMAT_RGBAF, data)
    texture = ImageTexture.create_from_image(image)

func w_poly6(dest: float, radius: float) -> float:
    if dest > radius:
        return 0
    var k_poly6 = 4 / (PI * pow(radius, 8))
    return k_poly6 * pow(radius * radius - dest * dest, 3)

func update_spatial_lookup():
    for i in range(particle_num):
        var cell_coord = position_to_cell_coord(particle_positions[i])
        var key = hash_cell(cell_coord)
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

func hash_cell(coord: Vector2i) -> int:
    return ((coord.x * 15823 + coord.y * 9737333) & 0x7fffffff) % particle_num

func enumerate_within_radius(point: Vector2) -> PackedInt32Array:
    var center = position_to_cell_coord(point)
    var indices: PackedInt32Array = []

    for dx in range(-1, 2):
        for dy in range(-1, 2):
            var key = hash_cell(center + Vector2i(dx, dy))
            var start = start_indices[key]
            for i in range(start, particle_num):
                if spatial_lookup[i].y != key:
                    break
                if point.distance_to(particle_positions[spatial_lookup[i].x]) > smooth_radius:
                    continue
                indices.push_back(spatial_lookup[i].x)

    return indices

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
        dt
    ])

func init_gpu_resources():
    rd = RenderingServer.create_local_rendering_device()
    
    compute_shaders.push_back(get_shader("res://compute_density.glsl"))
    compute_shaders.push_back(get_shader("res://compute_force.glsl"))
    compute_shaders.push_back(get_shader("res://compute_position.glsl"))

    gpu_buffers = [
        create_buffer(get_params_array().to_byte_array()),
        create_buffer(particle_positions.to_byte_array()),
        create_buffer(particle_velocities.to_byte_array()),
        create_buffer(particle_densities.to_byte_array()),
        create_buffer(particle_external_forces.to_byte_array()),
        create_buffer(vec2i_to_int32_array(spatial_lookup).to_byte_array()),
        create_buffer(start_indices.to_byte_array())
    ]

    var uniforms: Array[RDUniform] = []
    for i in range(gpu_buffers.size()):
        var uniform := RDUniform.new()
        uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
        uniform.binding = i
        uniform.add_id(gpu_buffers[i])
        uniforms.append(uniform)
    uniform_set = rd.uniform_set_create(uniforms, compute_shaders[0], 0)
    assert(uniform_set.is_valid())

    for shader in compute_shaders:
        var pipeline = rd.compute_pipeline_create(shader)
        assert(pipeline.is_valid())
        compute_pipelines.push_back(pipeline)

    var vertexs: PackedVector2Array = []
    for i in particle_positions:
        vertexs.push_back(Vector2(i.x / width * 2, i.y / height * 2))
    var vertexs_bytes = vertexs.to_byte_array()
    vertex_buffer = rd.vertex_buffer_create(vertexs_bytes.size(), vertexs_bytes)

    var vertex_description: Array[RDVertexAttribute] = [
        RDVertexAttribute.new()
    ]
    vertex_description[0].format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
    vertex_description[0].location = 0
    vertex_description[0].offset = 0
    vertex_description[0].stride = 4 * 2

    var vertex_format = rd.vertex_format_create(vertex_description)
    vertex_array = rd.vertex_array_create(particle_num, vertex_format, [vertex_buffer])

    var frametexture_format := RDTextureFormat.new()
    frametexture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    frametexture_format.width = int(width)
    frametexture_format.height = int(height)
    frametexture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT \
                                    | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    framebuffer_texture = rd.texture_create(frametexture_format, RDTextureView.new())

    var framebuffer_attachment: Array[RDAttachmentFormat] = [
        RDAttachmentFormat.new()
    ]
    framebuffer_attachment[0].format = frametexture_format.format
    framebuffer_attachment[0].samples = RenderingDevice.TEXTURE_SAMPLES_1
    framebuffer_attachment[0].usage_flags = frametexture_format.usage_bits
    
    var framebuffer_format = rd.framebuffer_format_create(framebuffer_attachment);
    framebuffer = rd.framebuffer_create([framebuffer_texture], framebuffer_format)

    render_shader = get_shader("res://render.glsl")

    var color_blend_state := RDPipelineColorBlendState.new()
    var color_blend_attachment = RDPipelineColorBlendStateAttachment.new()
    color_blend_attachment.write_r = true
    color_blend_attachment.write_g = true
    color_blend_attachment.write_b = true
    color_blend_attachment.write_a = true
    color_blend_state.attachments.append(color_blend_attachment)

    render_pipeline = rd.render_pipeline_create(
        render_shader,
        framebuffer_format,
        vertex_format,
        RenderingDevice.RENDER_PRIMITIVE_POINTS,
        RDPipelineRasterizationState.new(),
        RDPipelineMultisampleState.new(),
        RDPipelineDepthStencilState.new(),
        color_blend_state
    )

func call_gpu():
    update_buffer(gpu_buffers[0], get_params_array().to_byte_array())
    update_buffer(gpu_buffers[4], particle_external_forces.to_byte_array())
    update_buffer(gpu_buffers[5], vec2i_to_int32_array(spatial_lookup).to_byte_array())
    update_buffer(gpu_buffers[6], start_indices.to_byte_array())

    var vertexs: PackedVector2Array = []
    for i in particle_positions:
        vertexs.push_back(Vector2(i.x / width * 2, i.y / height * 2))
    update_buffer(vertex_buffer, vertexs.to_byte_array())

    var group_count = ceil(particle_num / 256.0)
    
    var compute_list := rd.compute_list_begin()
    
    for pipeline in compute_pipelines:
        rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
        rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
        rd.compute_list_dispatch(compute_list, group_count, 1, 1)

        rd.compute_list_add_barrier(compute_list)

    rd.compute_list_end()

    var draw_list := rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_CLEAR_ALL, PackedColorArray([Color.WHITE]))
    rd.draw_list_bind_render_pipeline(draw_list, render_pipeline)
    rd.draw_list_bind_vertex_array(draw_list, vertex_array)
    rd.draw_list_draw(draw_list, false, particle_num)
    rd.draw_list_end()

    rd.submit()
    rd.sync ()

    particle_positions = rd.buffer_get_data(gpu_buffers[1]).to_vector2_array()