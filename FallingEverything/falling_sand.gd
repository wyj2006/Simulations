extends Sprite2D

@export var width: int = 256
@export var height: int = 256

enum PixelMaterial {None, Air, Sand}

var material_color = {
    PixelMaterial.Air: Color.WHITE,
    PixelMaterial.Sand: Color.BLUE
}
var materials: PackedByteArray
var image: Image
var check_order := 0

@onready var rigidbody = $RigidBody2D
@onready var rigidbody_sprite = $RigidBody2D/Sprite2D
@onready var rigidbody_texture = rigidbody_sprite.texture
@onready var rigidbody_image: Image = rigidbody_texture.get_image()

var collision_polygons: Array[CollisionPolygon2D] = []

func _ready() -> void:
    materials.resize(width * height)
    materials.fill(PixelMaterial.Air)

    for i in range(width):
        materials[i + (width - 1) * height] = PixelMaterial.Sand

    image = Image.create(width, height, false, Image.FORMAT_RGBA8)
    texture = ImageTexture.create_from_image(image)

    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    offset = Vector2(width / 2.0, height / 2.0)

func _process(_delta: float) -> void:
    var rigidbody_pixels = {}
    for i in range(ceil(rigidbody_image.get_width() * rigidbody_sprite.scale.x)):
        for j in range(ceil(rigidbody_image.get_height() * rigidbody_sprite.scale.y)):
            @warning_ignore("shadowed_variable_base_class")
            var offset = Vector2(-rigidbody_image.get_width() * rigidbody_sprite.scale.x / 2.0, -rigidbody_image.get_height() * rigidbody_sprite.scale.y / 2.0)
            var pos = rigidbody.transform * (Vector2(i, j) + offset)
            var x = int(pos.x)
            var y = int(pos.y)
            if !(0 <= x && x < width) or !(0 <= y && y < height):
                continue
            rigidbody_pixels[Vector2i(x, y)] = rigidbody_image.get_pixelv(Vector2i(Vector2(i, j) / rigidbody_sprite.scale))

    for y in range(height - 1, -1, -1):
        for x in range(width):
            var index = y * width + x

            var down_index = (y + 1) * width + x
            var down = PixelMaterial.None
            if down_index < materials.size():
                down = materials[down_index] as PixelMaterial

            var left_down_index = down_index - 1
            var left_down = PixelMaterial.None
            if left_down_index < materials.size():
                left_down = materials[left_down_index] as PixelMaterial

            var right_down_index = down_index + 1
            var right_down = PixelMaterial.None
            if right_down_index < materials.size():
                right_down = materials[right_down_index] as PixelMaterial

            match materials[index]:
                PixelMaterial.Sand:
                    if down == PixelMaterial.Air and Vector2i(x, y + 1) not in rigidbody_pixels:
                        materials[index] = PixelMaterial.Air
                        materials[down_index] = PixelMaterial.Sand
                    elif check_order == 0:
                        if left_down == PixelMaterial.Air and Vector2i(x - 1, y + 1) not in rigidbody_pixels:
                            materials[index] = PixelMaterial.Air
                            materials[left_down_index] = PixelMaterial.Sand
                        elif right_down == PixelMaterial.Air and Vector2i(x + 1, y + 1) not in rigidbody_pixels:
                            materials[index] = PixelMaterial.Air
                            materials[right_down_index] = PixelMaterial.Sand
                    elif check_order == 1:
                        if right_down == PixelMaterial.Air and Vector2i(x + 1, y + 1) not in rigidbody_pixels:
                            materials[index] = PixelMaterial.Air
                            materials[right_down_index] = PixelMaterial.Sand
                        elif left_down == PixelMaterial.Air and Vector2i(x - 1, y + 1) not in rigidbody_pixels:
                            materials[index] = PixelMaterial.Air
                            materials[left_down_index] = PixelMaterial.Sand
            check_order = 1 - check_order

    var bitmap := BitMap.new()
    bitmap.create(image.get_size())

    var pixels := image.get_data()
    for x in range(width):
        for y in range(height):
            var index = y * width + x
            if materials[index] == PixelMaterial.Sand:
                bitmap.set_bit(x, y, true)

            var c: Color = material_color[materials[index]]
            index = index * 4
            pixels[index] = int(c.r * 255)
            pixels[index + 1] = int(c.g * 255)
            pixels[index + 2] = int(c.b * 255)
            pixels[index + 3] = 255
    image.set_data(width, height, false, Image.FORMAT_RGBA8, pixels)

    for key in rigidbody_pixels:
        image.set_pixelv(key, rigidbody_pixels[key])

    texture.update(image)

    var polygons = bitmap.opaque_to_polygons(Rect2(Vector2(), image.get_size()), 0)
    var i = 0
    while i < polygons.size():
        var polygon = polygons[i]
        if i >= collision_polygons.size():
            var static_body = StaticBody2D.new()
            var collision_polygon = CollisionPolygon2D.new()
            static_body.add_child(collision_polygon)
            add_child(static_body)
            collision_polygons.push_back(collision_polygon)
        collision_polygons[i].polygon = polygon
        i += 1
    while i < collision_polygons.size():
        var collision_polygon = collision_polygons.pop_back()
        remove_child(collision_polygon.get_parent())

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var mouse_pos: Vector2 = get_local_mouse_position()
        var x := int(mouse_pos.x)
        var y := int(mouse_pos.y)

        var index = y * width + x
        if 0 <= index and index < materials.size():
            materials[index] = PixelMaterial.Sand
