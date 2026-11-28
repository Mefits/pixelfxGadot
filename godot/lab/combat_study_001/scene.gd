extends Node2D
const World=preload("res://lab/combat_study_001/world.gd")
const View=preload("res://lab/combat_study_001/view.gd")
var world
var view=View.new()
var sprite:Sprite2D
var hud:Label
var pending:Array=["",""]
var paused:bool=false
var accum:float=0.
var gap:float=28.
var last_result:String=""

func _ready()->void:
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.position=Vector2(0,75)
    sprite.scale=Vector2(1.5,1.5)
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    hud=Label.new()
    hud.position=Vector2(16,10)
    add_child(hud)
    var hint=Label.new()
    hint.position=Vector2(16,492)
    hint.text="P1: D forward | F jab G cross H kick S guard   P2: Left forward | K jab L cross O kick Down guard\nSpace pause | P single tick | R reset | +/- starting distance | Esc menu"
    add_child(hint)
    reset()
    
func reset()->void:
    world=World.new(gap)
    pending=["",""]
    accum=0.
    last_result=""
    redraw()

func advance()->void:
    if view.raster==null:return
    var a:Dictionary={"action":pending[0],"forward":Input.is_physical_key_pressed(KEY_D),"guard":Input.is_physical_key_pressed(KEY_S)}
    var b:Dictionary={"action":pending[1],"forward":Input.is_physical_key_pressed(KEY_LEFT),"guard":Input.is_physical_key_pressed(KEY_DOWN)}
    pending=["",""]
    world.step(a,b)
    for e in world.events:last_result="%s %s %s"%[e.attacker+1,e.attack,e.result]
    redraw()

func redraw()->void:
    if view.raster==null:
        hud.text="Native PixelFX required"
        return
    var im:Image=view.render(world)
    if im==null:
        hud.text="Native render error"
        return
    if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
    else:sprite.texture.update(im)
    var a:Dictionary=world.actors[0]
    var b:Dictionary=world.actors[1]
    hud.text="COMBAT LAB 0.01   /   Hybrid 0.91   /   60 Hz\nHP %d : %d | %s %d / %s %d | stun %d : %d | freeze %d | tick %d | %s"%[a.hp,b.hp,a.action,a.remaining,b.action,b.remaining,a.stun,b.stun,world.freeze,world.tick,last_result]

func _process(dt:float)->void:
    if paused:return
    accum+=minf(dt,.1)
    while accum>=1./60.:
        advance()
        accum-=1./60.

func _unhandled_input(e:InputEvent)->void:
    if not e is InputEventKey or not e.pressed or e.echo:return
    match e.physical_keycode:
        KEY_F:pending[0]="jab"
        KEY_G:pending[0]="cross"
        KEY_H:pending[0]="kick"
        KEY_K:pending[1]="jab"
        KEY_L:pending[1]="cross"
        KEY_O:pending[1]="kick"
        KEY_SPACE:paused=not paused
        KEY_P:
            if paused:advance()
        KEY_R:reset()
        KEY_EQUAL:gap=clampf(gap+2.,16.,90.);reset()
        KEY_MINUS:gap=clampf(gap-2.,16.,90.);reset()
        KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
