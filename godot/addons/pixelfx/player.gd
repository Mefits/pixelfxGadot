extends Node2D
signal finished
var clip
var elapsed: float = 0.0
var active: bool = false
var frame_index: int = -1
var page_index: int = -1
var color_sprite := Sprite2D.new()
var light_sprite := Sprite2D.new()

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var plain := CanvasItemMaterial.new()
    plain.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    color_sprite.material = plain
    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    light_sprite.material = additive
    for sprite: Sprite2D in [color_sprite, light_sprite]:
        sprite.centered = false
        sprite.region_enabled = true
        sprite.region_filter_clip_enabled = true
        add_child(sprite)
    # Keep the two layers adjacent in the draw order of each player.
    hide()
    set_process(false)

func play_clip(value, at: Vector2, facing: int = 1, pixel_scale: float = 1.0) -> void:
    if value == null or value.frames.is_empty():
        return
    clip = value
    global_position = at
    scale = Vector2(-pixel_scale if facing < 0 else pixel_scale, pixel_scale)
    color_sprite.position = -clip.pivot
    light_sprite.position = -clip.pivot
    elapsed = 0.0
    frame_index = -1
    page_index = -1
    active = true
    _show_frame(0)
    show()
    set_process(true)

func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    if not clip.loops and elapsed >= clip.duration:
        stop()
        finished.emit()
        return
    var t: float = fposmod(elapsed, clip.duration) if clip.loops else elapsed
    _show_frame(clampi(int(floor(t * clip.fps)), 0, clip.frames.size() - 1))

func _show_frame(index: int) -> void:
    if index == frame_index:
        return
    frame_index = index
    var p: int = clip.page_indices[index]
    if p != page_index:
        page_index = p
        color_sprite.texture = clip.colors[p]
        light_sprite.texture = clip.lights[p]
    color_sprite.region_rect = clip.frames[index]
    light_sprite.region_rect = clip.frames[index]

func stop() -> void:
    active = false
    hide()
    set_process(false)
