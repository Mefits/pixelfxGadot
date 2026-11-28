extends Node2D
const W=preload("res://lab/ability_study_001/world.gd")
const View=preload("view.gd")
const Trace=preload("trace.gd")
var world
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
    world=W.new(Trace.GAP)
    t=0
    view.reset()
func _process(dt:float)->void:
    if view.raster==null:
        label.text="Native PixelFX required"
        return
    accumulator+=minf(dt,.1)
    while accumulator>=1./60.:
        if t>=Trace.TICKS:reset()
        var c:Array=Trace.commands(t)
        world.step(c[0],c[1])
        t+=1
        accumulator-=1./60.
        var im:Image=view.render(world)
        if im==null:return
        if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
        else:sprite.texture.update(im)
    label.text="Aura Lab 0.01 | 0 baseline / 1 cloak / 2 tail / 3 twin tails | R restart | %d | tick %d"%[view.mode,t]
func _unhandled_input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo:return
    if event.physical_keycode in [KEY_0,KEY_1,KEY_2,KEY_3]:
        view.mode=event.physical_keycode-KEY_0
        reset()
    elif event.physical_keycode==KEY_R:reset()
