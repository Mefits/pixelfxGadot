extends Node2D
const W=preload("res://lab/aura_study_003/world.gd")
const View=preload("view.gd")
const Trace=preload("trace.gd")
var world
var variant:int=1
var view=View.new()
var sprite:Sprite2D
var label:Label
var t:int=0
var accumulator:float=0.
func _ready()->void:
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.position=Vector2(0,80)
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    label=Label.new()
    label.position=Vector2(16,12)
    add_child(label)
    reset()
func reset()->void:
    world=W.new(48.,variant)
    t=0
    view.reset()
func _process(dt:float)->void:
    if view.raster==null or view.native_aura==null:
        label.text="Native PixelFX required"
        return
    accumulator+=minf(dt,.1)
    while accumulator>=1./60.:
        if t>=Trace.TICKS:reset()
        var c:Array=Trace.commands(t,"hit")
        world.step(c[0],c[1])
        t+=1
        accumulator-=1./60.
        var im:Image=view.render(world)
        if im==null:return
        if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
        else:sprite.texture.update(im)
    label.text="Aura Lab 0.03 | 0 sharp / 1 balanced / 2 heavy | R restart | %d | tick %d"%[variant,t]
func _unhandled_input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo:return
    if event.physical_keycode in [KEY_0,KEY_1,KEY_2]:
        variant=event.physical_keycode-KEY_0
        reset()
    elif event.physical_keycode==KEY_R:reset()
