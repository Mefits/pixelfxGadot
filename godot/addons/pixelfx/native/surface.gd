extends Node2D
## Presents a native CPU Painter with two persistent texture objects.
## A single texture upload per buffer per visual update, no per-pixel CanvasItems.
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")
var painter
var color_image: Image
var light_image: Image
var color_texture: ImageTexture
var light_texture: ImageTexture
var color_sprite := Sprite2D.new()
var light_sprite := Sprite2D.new()

func _ready() -> void:
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    var plain:=CanvasItemMaterial.new()
    plain.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
    color_sprite.material=plain
    var additive:=CanvasItemMaterial.new()
    additive.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
    additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
    light_sprite.material=additive
    for sprite: Sprite2D in [color_sprite,light_sprite]:
        sprite.centered=false
        add_child(sprite)

func configure(w: int,h: int) -> void:
    painter=PAINTER.new(w,h)
    color_image=Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,painter.rgba_bytes())
    light_image=Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,painter.rgba_bytes(true))
    color_texture=ImageTexture.create_from_image(color_image)
    light_texture=ImageTexture.create_from_image(light_image)
    color_sprite.texture=color_texture
    light_sprite.texture=light_texture

func present() -> void:
    if painter==null:
        return
    color_image.set_data(painter.width,painter.height,false,Image.FORMAT_RGBA8,painter.rgba_bytes())
    light_image.set_data(painter.width,painter.height,false,Image.FORMAT_RGBA8,painter.rgba_bytes(true))
    color_texture.update(color_image)
    light_texture.update(light_image)
