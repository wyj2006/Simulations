extends Sprite2D

@export var width: int = 256
@export var height: int = 256

enum PixelMaterial {None, Air, Sand}

var material_color = {
    PixelMaterial.Air: Color.WHITE,
    PixelMaterial.Sand: Color.BLACK
}
var materials: PackedByteArray
var image: Image
var check_order := 0

func _ready() -> void:
    materials.resize(width * height)
    materials.fill(PixelMaterial.Air)

    # for i in range(materials.size()):
    #     if randi_range(0, 10) == 0:
    #         materials[i] = PixelMaterial.Sand

    image = Image.create(width, height, false, Image.FORMAT_RGBA8)
    texture = ImageTexture.create_from_image(image)

    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
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
                    if down == PixelMaterial.Air:
                        materials[index] = PixelMaterial.Air
                        materials[down_index] = PixelMaterial.Sand
                    elif check_order == 0:
                        if left_down == PixelMaterial.Air:
                            materials[index] = PixelMaterial.Air
                            materials[left_down_index] = PixelMaterial.Sand
                        elif right_down == PixelMaterial.Air:
                            materials[index] = PixelMaterial.Air
                            materials[right_down_index] = PixelMaterial.Sand
                    elif check_order == 1:
                        if right_down == PixelMaterial.Air:
                            materials[index] = PixelMaterial.Air
                            materials[right_down_index] = PixelMaterial.Sand
                        elif left_down == PixelMaterial.Air:
                            materials[index] = PixelMaterial.Air
                            materials[left_down_index] = PixelMaterial.Sand
            check_order = 1 - check_order

    var pixels := image.get_data()
    for i in range(materials.size()):
        var c: Color = material_color[materials[i]]
        var index := i * 4
        pixels[index] = int(c.r * 255)
        pixels[index + 1] = int(c.g * 255)
        pixels[index + 2] = int(c.b * 255)
        pixels[index + 3] = 255
    image.set_data(width, height, false, Image.FORMAT_RGBA8, pixels)
    texture.update(image)

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var mouse_pos: Vector2 = get_local_mouse_position()
        var x := int(mouse_pos.x + width / 2.0)
        var y := int(mouse_pos.y + height / 2.0)

        for i in range(0, 1):
            for j in range(0, 1):
                var index = (y + j) * width + x + i
                # if randi_range(0, 10) != 0:
                #     continue
                if index >= materials.size():
                    continue
                materials[index] = PixelMaterial.Sand