extends Control
const CAT=preload("res://addons/creature/catalog.gd")
var catalog_entry:Dictionary={}
const UI=preload("res://lab/ui_ru.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const COMBAT=preload("res://addons/creature/combat.gd")
const CANVAS=preload("res://lab/combat_canvas.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const FX=preload("res://addons/creature/vfx_runtime.gd")
const ABILITY=preload("res://addons/creature/ability.gd")
const ABILITY_EDITOR=preload("res://lab/ability_dialog.gd")
const BINDINGS=preload("res://addons/creature/vfx_bindings.gd")
var world
var ability_editor
var phase_label: Label
var ability_profile: Dictionary={}
var canvas
var surface
var bolt=L.new()
var batch=BATCH.new()
var palette: Array=PAL.fit(L.VOLT,8)
var bot: bool=true
var debug: bool=false
var modern: bool=true
var effects_on: bool=true
var slow: bool=false
var training: bool=false
var detail: Label
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
    hud.position=Vector2(24,46)
    hud.add_theme_font_size_override("font_size",14)
    add_child(hud)
    detail=Label.new()
    detail.position=Vector2(24,68)
    detail.add_theme_font_size_override("font_size",13)
    add_child(detail)
    var info:=Label.new()
    info.position=Vector2(24,492)
    info.text="Игрок 1: A/D ходьба · W прыжок · F удар / в воздухе · H тяжёлый · J ногой · G магия · S блок\nИгрок 2: стрелки · K удар · L магия · O тяжёлый · P ногой | B бот · N динамика · X медл. · C эффекты · M трен. · R сброс · Tab редактор · Esc"
    info.add_theme_font_size_override("font_size",13)
    add_child(info)
    catalog_entry=CAT.consume(get_tree(),"ability")
    ability_profile=ABILITY.load_profile() if catalog_entry.is_empty() else catalog_entry.payload.duplicate(true)
    phase_label=Label.new()
    phase_label.position=Vector2(24,90)
    phase_label.add_theme_font_size_override("font_size",13)
    add_child(phase_label)
    ability_editor=ABILITY_EDITOR.new()
    add_child(ability_editor)
    ability_editor.applied.connect(_apply_ability)
    _reset()

func _apply_ability(profile: Dictionary) -> void:
    if not catalog_entry.is_empty():
        var saved:Dictionary=CAT.save_draft(catalog_entry,profile,profile.name)
        if saved.is_empty():return
        catalog_entry=saved
    elif not ABILITY.save_profile(profile):return
    ability_profile=profile
    _reset()

func _bar(at: Vector2) -> ProgressBar:
    var b:=ProgressBar.new()
    b.position=at
    b.size=Vector2(330,22)
    b.max_value=100
    b.value=100
    b.show_percentage=false
    var bg:=StyleBoxFlat.new()
    bg.bg_color=Color("#29394a")
    var fill:=StyleBoxFlat.new()
    fill.bg_color=Color("#5aafdc") if at.x<300 else Color("#ce775f")
    b.add_theme_stylebox_override("background",bg)
    b.add_theme_stylebox_override("fill",fill)
    add_child(b)
    return b

func _reset() -> void:
    world=COMBAT.new(CLIPS.fighter_bank(0),CLIPS.fighter_bank(1))
    world.custom_vfx=FX.new(BINDINGS.load_bank())
    world.custom_vfx.renderer.enable_acceleration(cpp)
    world.a.set_ability(ability_profile)
    canvas.world=world
    world.modern=modern
    if training:
        world.a.pos.x=130
        world.b.pos.x=155
    ai_clock=0

func _pressed(code: Key) -> bool:
    return Input.is_physical_key_pressed(code)

func _physics_process(dt: float) -> void:
    if world==null:return
    if ability_editor!=null and ability_editor.visible:return
    var left: Dictionary={"move":float(_pressed(KEY_D))-float(_pressed(KEY_A)),"jump":_pressed(KEY_W),"strike":_pressed(KEY_F),"cast":_pressed(KEY_G),"heavy":_pressed(KEY_H),"kick":_pressed(KEY_J),"ability":_pressed(KEY_E),"guard":_pressed(KEY_S)}
    var right: Dictionary={"move":float(_pressed(KEY_RIGHT))-float(_pressed(KEY_LEFT)),"jump":_pressed(KEY_UP),"strike":_pressed(KEY_K),"cast":_pressed(KEY_L),"heavy":_pressed(KEY_O),"kick":_pressed(KEY_P),"guard":_pressed(KEY_DOWN)}
    if training:right={}
    elif bot:
        ai_clock+=dt
        var dist: float=world.a.pos.x-world.b.pos.x
        if ai_clock>.85:
            ai_clock=0
            ai_action=(ai_action+1)%6
        right={"move":signf(dist) if absf(dist)>31 else 0.0,"strike":absf(dist)<35 and ai_action==0,"cast":absf(dist)<95 and ai_action==1,"guard":ai_action==2 and absf(dist)<70,"heavy":absf(dist)<36 and ai_action==4,"kick":absf(dist)<35 and ai_action==5}
    world.step(dt*(.35 if slow else 1),left,right)
    hp1.value=world.a.hp
    hp2.value=world.b.hp
    canvas.debug=debug
    canvas.queue_redraw()
    charge_tick+=dt
    if charge_tick>=1.0/30:
        charge_tick=fmod(charge_tick,1.0/30)
        _vfx()
    _update_hud()

func _update_hud() -> void:
    hp1.value=world.a.hp
    hp2.value=world.b.hp
    detail.text="Динамика: %s · %s · посл. серия %d (макс. %d) · блоков %d · F→F→G после попадания"%["новая" if modern else "старая","тренировка" if training else ("медленно" if slow else "бой"),world.combo,world.best_combo,world.blocks]
    var phase: String=ABILITY.phase_at(world.a.ability,world.a.t) if world.a.state=="ability" else ""
    phase_label.text="E — "+str(ability_profile.get("name","Способность"))+" · Q — настройка | "+str({"charge":"Заряд","dash":"Рывок","contact":"Контакт","recovery":"Восстановление","done":"Конец"}.get(phase,"Готова"))
    hud.text="БОЕВАЯ ЛАБОРАТОРИЯ | %s | здоровье %d : %d | попаданий %d | эффекты %.2f мс | %s"%["ТРЕНИРОВКА" if training else ("БОТ" if bot else "2 ИГРОКА"),world.a.hp,world.b.hp,world.hits,vfx_ms,"C++" if cpp else "GDScript"]

func _vfx() -> void:
    var start: int=Time.get_ticks_usec()
    var p=surface.painter
    p.clear()
    if not effects_on:
        surface.present()
        return
    var d=batch.begin(p)
    for f in world.flashes:
        if f.get("custom",false):continue
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
        elif f.kind in ["impact","block"]:
            var p0: Vector2=f.a
            var r0=RNG.new(178)
            var color: int=PAL.from_hex("#ffe0a0" if f.kind=="impact" else "#82dedc")
            for j in range(9):
                var angle: float=r0.between(-PI,PI)
                var v: Vector2=Vector2.from_angle(angle)
                var q: Vector2=p0+v*(4+f.age*85)
                d.line(q.x,q.y,q.x-v.x*4,q.y-v.y*4,color,k)
            d.glow(p0.x,p0.y,12,color,.6*k)
    batch.finish()
    for f in world.flashes:
        if f.get("custom",false):continue
        if f.kind=="cast":
            var a: Vector2=f.a
            var b: Vector2=f.b
            var k: float=1-f.age/f.life
            var r=RNG.new(int(f.age*30)+121)
            bolt.stroke(p,L.zigzag(r,a.x,a.y,b.x,b.y,.24,.5),k,palette,.65)
    world.custom_vfx.draw(p,146.0)
    surface.present()
    vfx_ms=(Time.get_ticks_usec()-start)/1000.0

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        match UI.physical_key(e):
            KEY_Q:ability_editor.open_for(ability_profile)
            KEY_B:bot=not bot
            KEY_R:_reset()
            KEY_V:debug=not debug
            KEY_N:
                modern=not modern
                world.modern=modern
            KEY_X:slow=not slow
            KEY_C:
                effects_on=not effects_on
                _vfx()
            KEY_M:
                training=not training
                _reset()
            KEY_TAB:get_tree().change_scene_to_file("res://lab/pose_workshop.tscn")
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
