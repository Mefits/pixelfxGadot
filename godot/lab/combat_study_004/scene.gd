extends Node2D
const World=preload("res://lab/combat_study_004/world.gd")
const View=preload("res://lab/combat_study_004/view.gd")
var world
var view=View.new()
var sprite:Sprite2D
var hud:Label
var pending:Array=["",""]
var paused:bool=false
var accum:float=0.
var gap:float=30.
var profile:int=2
const Policy=preload("res://lab/combat_study_002/policy.gd")
var last_result:String=""

func _ready()->void:
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.position=Vector2(0,75)
    sprite.scale=Vector2(1.25,1.25)
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    hud=Label.new()
    hud.position=Vector2(16,10)
    add_child(hud)
    var hint=Label.new()
    hint.position=Vector2(16,492)
    hint.text="P1 D F/G/H Q/E/T | W chase | F air strike Q air pulse H slam | S guard\nP2 Left K/L/O U/I/Y | Up chase | K air strike U air pulse O slam | 1/2/3 policy | Space/P pause/step"
    add_child(hint)
    reset()
    
func reset()->void:
    world=World.new(gap,true,profile)
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
    hud.text="COMBAT LAB 0.04   /   %s   /   60 Hz\nHP %d : %d | %s %d / %s %d | stun %d : %d | freeze %d | tick %d | %s"%[Policy.NAMES[profile],a.hp,b.hp,a.action,a.remaining,b.action,b.remaining,a.stun,b.stun,world.freeze,world.tick,last_result]

func _process(dt:float)->void:
    if paused:return
    accum+=minf(dt,.1)
    while accum>=1./60.:
        advance()
        accum-=1./60.

func _unhandled_input(e:InputEvent)->void:
    if not e is InputEventKey or not e.pressed or e.echo:return
    match e.physical_keycode:
        KEY_1:profile=0;reset()
        KEY_2:profile=1;reset()
        KEY_3:profile=2;reset()
        KEY_W:pending[0]="chase"
        KEY_UP:pending[1]="chase"
        KEY_Q:pending[0]="air_pulse" if world.airborne(0) else "pulse"
        KEY_E:pending[0]="dash"
        KEY_T:pending[0]="launch"
        KEY_U:pending[1]="air_pulse" if world.airborne(1) else "pulse"
        KEY_I:pending[1]="dash"
        KEY_Y:pending[1]="launch"
        KEY_F:pending[0]="air_cross" if world.airborne(0) else "jab"
        KEY_G:pending[0]="cross"
        KEY_H:pending[0]="slam" if world.airborne(0) else "kick"
        KEY_K:pending[1]="air_cross" if world.airborne(1) else "jab"
        KEY_L:pending[1]="cross"
        KEY_O:pending[1]="slam" if world.airborne(1) else "kick"
        KEY_SPACE:paused=not paused
        KEY_P:
            if paused:advance()
        KEY_R:reset()
        KEY_EQUAL:gap=clampf(gap+2.,16.,90.);reset()
        KEY_MINUS:gap=clampf(gap-2.,16.,90.);reset()
        KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
