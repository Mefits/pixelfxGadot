extends Node2D
const World=preload("res://lab/combat_study_006/world.gd")
const View=preload("res://lab/combat_study_005/view.gd")
var world
var view=View.new()
var sprite:Sprite2D
var hud:Label
var pending:Array=[0,0]
const Control=preload("res://lab/combat_study_006/control.gd")
var paused:bool=false
var accum:float=0.
var gap:float=30.
var profile:int=2
const Policy=preload("res://lab/combat_study_002/policy.gd")
var last_result:String=""
const Bot=preload("res://lab/combat_study_006/bot.gd")
var bot_enabled:bool=false
var history:Array=[]

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
    hint.text="P1 A/D move F/G/H attacks Shift modifier W chase Q parry/escape S guard\nP2 Left/Right K/L/O attacks Ctrl modifier Up chase U parry/escape Down guard | B bot | 1/2/3 policy"
    add_child(hint)
    reset()
    
func reset()->void:
    world=World.new(gap,true,profile)
    pending=[0,0]
    accum=0.
    last_result=""
    history=[]
    redraw()

func advance()->void:
    if view.raster==null:return
    var a:Dictionary={"edge":pending[0],"forward":Input.is_physical_key_pressed(KEY_D),"back":Input.is_physical_key_pressed(KEY_A),"guard":Input.is_physical_key_pressed(KEY_S),"modifier":Input.is_physical_key_pressed(KEY_SHIFT)}
    var b:Dictionary={"edge":pending[1],"forward":Input.is_physical_key_pressed(KEY_LEFT),"back":Input.is_physical_key_pressed(KEY_RIGHT),"guard":Input.is_physical_key_pressed(KEY_DOWN),"modifier":Input.is_physical_key_pressed(KEY_CTRL)}
    pending=[0,0]
    history.append(Bot.observe(world))
    if bot_enabled:b=Bot.command(history[maxi(0,history.size()-7)],1,2,world.tick)
    if history.size()>7:history.pop_front()
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
    hud.text="COMBAT LAB 0.06   /   %s   /   60 Hz\nHP %d : %d | %s %d / %s %d | stun %d : %d | freeze %d | tick %d | %s"%[Policy.NAMES[profile],a.hp,b.hp,a.action,a.remaining,b.action,b.remaining,a.stun,b.stun,world.freeze,world.tick,last_result]+" | escape %d:%d | bot %s"%[int(not a.escape_used),int(not b.escape_used),str(bot_enabled)]

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
        KEY_B:bot_enabled=not bot_enabled
        KEY_F:pending[0]=int(pending[0])|Control.LIGHT
        KEY_G:pending[0]=int(pending[0])|Control.HEAVY
        KEY_H:pending[0]=int(pending[0])|Control.SKILL
        KEY_W:pending[0]=int(pending[0])|Control.MOBILITY
        KEY_Q:pending[0]=int(pending[0])|Control.DEFENSE
        KEY_K:pending[1]=int(pending[1])|Control.LIGHT
        KEY_L:pending[1]=int(pending[1])|Control.HEAVY
        KEY_O:pending[1]=int(pending[1])|Control.SKILL
        KEY_UP:pending[1]=int(pending[1])|Control.MOBILITY
        KEY_U:pending[1]=int(pending[1])|Control.DEFENSE
        KEY_SPACE:paused=not paused
        KEY_P:
            if paused:advance()
        KEY_R:reset()
        KEY_EQUAL:gap=clampf(gap+2.,16.,90.);reset()
        KEY_MINUS:gap=clampf(gap-2.,16.,90.);reset()
        KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")

func _notification(what:int)->void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        pending=[0,0]
        paused=true
