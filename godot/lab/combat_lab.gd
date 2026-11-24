extends Control
const CLIPS=preload("res://addons/creature/clips.gd")
const COMBAT=preload("res://addons/creature/combat.gd")
const CANVAS=preload("res://lab/combat_canvas.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const RNG=preload("res://addons/pixelfx/native/rng.gd")
var world
var canvas
var surface
var bolt=L.new()
var batch=BATCH.new()
var palette: Array=PAL.fit(L.VOLT,8)
var bot: bool=true
var debug: bool=false
var hud: Label
var hp1: ProgressBar
var hp2: ProgressBar
var charge_tick: float=0
var ai_clock: float=0
var ai_action: int=0
var vfx_ms: float=0
var cpp: bool=false

func _ready() -> void:
    var view:=SubViewport.new()
    view.size=Vector2i(320,180)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(view)
    canvas=CANVAS.new()
    view.add_child(canvas)
    surface=SURFACE.new()
    view.add_child(surface)
    surface.configure(320,180)
    var picture:=TextureRect.new()
    picture.position=Vector2.ZERO
    picture.size=Vector2(960,540)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture=view.get_texture()
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(picture)
    cpp=bolt.enable_acceleration() and batch.enable_acceleration()
    hp1=_bar(Vector2(24,17))
    hp2=_bar(Vector2(606,17))
    hud=Label.new()
    hud.position=Vector2(24,50)
    add_child(hud)
    var info:=Label.new()
    info.position=Vector2(24,503)
    info.text="P1 A/D W jump F strike G cast S guard | P2 arrows K strike L cast Down guard | B bot R reset Tab editor V joints"
    info.add_theme_font_size_override("font_size",13)
    add_child(info)
    _reset()

func _bar(at: Vector2) -> ProgressBar:
    var b:=ProgressBar.new()
    b.position=at
    b.size=Vector2(330,22)
    b.max_value=100
    b.value=100
    b.show_percentage=false
    add_child(b)
    return b

func _reset() -> void:
    world=COMBAT.new(CLIPS.load_bank())
    canvas.world=world
    ai_clock=0

func _pressed(code: Key) -> bool:
    return Input.is_physical_key_pressed(code)

func _physics_process(dt: float) -> void:
    if world==null:return
    var left: Dictionary={"move":float(_pressed(KEY_D))-float(_pressed(KEY_A)),"jump":_pressed(KEY_W),"strike":_pressed(KEY_F),"cast":_pressed(KEY_G),"guard":_pressed(KEY_S)}
    var right: Dictionary={"move":float(_pressed(KEY_RIGHT))-float(_pressed(KEY_LEFT)),"jump":_pressed(KEY_UP),"strike":_pressed(KEY_K),"cast":_pressed(KEY_L),"guard":_pressed(KEY_DOWN)}
    if bot:
        ai_clock+=dt
        var dist: float=world.a.pos.x-world.b.pos.x
        if ai_clock>.85:
            ai_clock=0
            ai_action=(ai_action+1)%4
        right={"move":signf(dist) if absf(dist)>31 else 0.0,"strike":absf(dist)<35 and ai_action==0,"cast":absf(dist)<95 and ai_action==1,"guard":ai_action==2 and absf(dist)<70}
    world.step(dt,left,right)
    hp1.value=world.a.hp
    hp2.value=world.b.hp
    canvas.debug=debug
    canvas.queue_redraw()
    charge_tick+=dt
    if charge_tick>=1.0/30:
        charge_tick=fmod(charge_tick,1.0/30)
        _vfx()
    hud.text="COMBAT LAB | %s | %d : %d HP | %d hits | %.2f ms VFX | %s"%["BOT" if bot else "2 PLAYERS",world.a.hp,world.b.hp,world.hits,vfx_ms,"C++" if cpp else "GDScript"]

func _vfx() -> void:
    var start: int=Time.get_ticks_usec()
    var p=surface.painter
    p.clear()
    var d=batch.begin(p)
    for f in world.flashes:
        var k: float=1-f.age/f.life
        if f.kind=="charge":
            var a: Vector2=f.owner.point(f.anchor)
            d.circle(a.x,a.y,2.5,palette[5])
            d.circle(a.x,a.y,1.5,palette[7])
            d.glow(a.x,a.y,15,palette[4],.5*k)
        elif f.kind=="strike":
            var a: Vector2=f.a
            var b: Vector2=f.b
            d.line(a.x,a.y-5,b.x,b.y,palette[6],k)
            d.glow(b.x,b.y,8,palette[5],.6*k)
    batch.finish()
    for f in world.flashes:
        if f.kind=="cast":
            var a: Vector2=f.a
            var b: Vector2=f.b
            var k: float=1-f.age/f.life
            var r=RNG.new(int(f.age*30)+121)
            bolt.stroke(p,L.zigzag(r,a.x,a.y,b.x,b.y,.24,.5),k,palette,.65)
    surface.present()
    vfx_ms=(Time.get_ticks_usec()-start)/1000.0

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        match e.keycode:
            KEY_B:bot=not bot
            KEY_R:_reset()
            KEY_V:debug=not debug
            KEY_TAB:get_tree().change_scene_to_file("res://lab/pose_workshop.tscn")
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
