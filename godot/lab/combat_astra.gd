extends Node2D
## Current Astra training stand: authored attack, event-based hit, local
## authored reaction. No dynamic collision or automatic ragdoll.
const Asset=preload("res://lab/authoring/asset.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const UI=preload("res://lab/ui_ru.gd")
const ORIGINS=[Vector2(350,414),Vector2(350,414)]
const SCALE:float=5.
var players:Array=[]
var sprites:Array=[]
var raster
var body=Body.new(2)
var manual:bool=false
var paused:bool=false
var last_ok:bool=false
var clock:float=0.
var ticks:int=0
var hits:Array=[0,0]
var hp:Array=[100,100]
var pending:Array=["",""]
var recoil:Array=[0.,0.]
var distance:float=24.
var hit_enabled:bool=true
var strength:float=1.
var status:Label
var distance_label:Label
var distance_slider:HSlider
var reaction_select:OptionButton

func _ready()->void:
    var header:=Label.new()
    header.position=Vector2(24,14)
    header.text="БОЙ / ASTRA — авторские атаки"
    header.add_theme_font_size_override("font_size",24)
    add_child(header)
    var hint:=Label.new()
    hint.position=Vector2(24,48)
    hint.text="F / K — джеб слева / справа · Space — пауза · R — сброс · Esc — меню"
    add_child(hint)
    var tools:=HBoxContainer.new()
    tools.position=Vector2(24,85)
    add_child(tools)
    button(tools,"F · Джеб A",func():queue_attack(0))
    button(tools,"K · Джеб B",func():queue_attack(1))
    button(tools,"Пауза",func():paused=not paused)
    button(tools,"Кадр",advance)
    button(tools,"Сброс",reset)
    button(tools,"Прежний бой",func():get_tree().change_scene_to_file("res://lab/combat_lab.tscn"))
    button(tools,"Меню",func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    var controls:=HBoxContainer.new()
    controls.position=Vector2(24,128)
    add_child(controls)
    distance_label=Label.new()
    controls.add_child(distance_label)
    distance_slider=HSlider.new()
    distance_slider.min_value=16.
    distance_slider.max_value=55.
    distance_slider.step=.5
    distance_slider.value=distance
    distance_slider.custom_minimum_size.x=180
    controls.add_child(distance_slider)
    distance_slider.value_changed.connect(func(v:float):distance=v;render_frame())
    reaction_select=OptionButton.new()
    reaction_select.add_item("Лёгкая реакция")
    reaction_select.add_item("Сильная реакция (без падения)")
    reaction_select.add_item("Эталон без попаданий")
    controls.add_child(reaction_select)
    reaction_select.item_selected.connect(func(i:int):hit_enabled=i!=2;strength=1. if i==0 else 2.)
    status=Label.new()
    status.position=Vector2(24,470)
    add_child(status)
    var note:=Label.new()
    note.position=Vector2(24,502)
    note.text="Тест дистанции и попаданий по маркеру Astra. Box2D выключен. Прежний игровой стенд сохранён."
    note.add_theme_font_size_override("font_size",13)
    add_child(note)
    if not ClassDB.class_exists("PixelFXBodyRaster"):
        status.text="Нативное тело не загружено. Используй полный Windows-пакет Lab."
        return
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    for i in 2:
        var sprite:=Sprite2D.new()
        sprite.centered=true
        sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.scale=Vector2.ONE*SCALE/3.
        sprite.flip_h=i==1
        sprite.z_index=-1
        add_child(sprite)
        sprites.append(sprite)
    reset()

func button(parent:Control,title:String,fn:Callable)->void:
    var b:=Button.new()
    b.text=title
    parent.add_child(b)
    b.pressed.connect(fn)

func reset()->void:
    if raster==null:return
    players.clear()
    var jab:Dictionary=Asset.read(Asset.DIR+"jab.json")
    if FileAccess.file_exists(Asset.FOLDER+"jab.json"):
        var saved:Dictionary=Asset.read(Asset.FOLDER+"jab.json")
        if Asset.problem(saved)=="" and saved.id=="jab":jab=saved
    for i in 2:
        var p=Asset.ensemble({},[jab],60)
        for t in 30:p.step({"speed":0.})
        players.append(p)
    hits=[0,0]
    hp=[100,100]
    pending=["",""]
    recoil=[0.,0.]
    ticks=0
    clock=0.
    render_frame()

func queue_attack(i:int)->void:
    pending[i]="jab"

func advance()->void:
    if players.size()!=2:return
    var centers:Array=[]
    for i in 2:centers.append(players[i].rig.point("chest"))
    var next_recoil:Array=[0.,0.]
    for i in 2:
        var p=players[i]
        var other:int=1-i
        var target:Vector2=Vector2(distance-centers[other].x,centers[other].y-2.)
        var cmd:Dictionary={"speed":0.,"impulse":recoil[i]}
        if pending[i]!="":cmd.action=pending[i]
        pending[i]=""
        if hit_enabled:
            cmd.hurt_center=target+Vector2.RIGHT*(p.gait.travel+(0. if p.stopped else move_toward(float(p.speed),1.,.035)))
            cmd.radius=7.
        p.step(cmd)
        for event in p.events:
            if bool(event[4]):
                hits[i]+=1
                hp[other]=maxi(0,hp[other]-(5 if strength==1. else 15))
                next_recoil[other]+=140.*strength
    recoil=next_recoil
    ticks+=1
    render_frame()

func render_frame()->void:
    if players.size()!=2:return
    last_ok=true
    for i in 2:
        var p=players[i]
        var parts:Array=body.make(p.rig.points,p.final_pose.angles,p.rig.rotations.head)
        Depth.apply(parts,p.style)
        for k in [0,2,3,8,9]:parts[k].material_id=1 if i==0 else 3
        for k in [5,6,7,11,12,13,15,17]:parts[k].material_id=2
        var result:Dictionary=raster.render(Studio.CFG,parts)
        if not result.get("ok",false):
            last_ok=false
            status.text="Ошибка нативной отрисовки."
            return
        var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
        if sprites[i].texture:sprites[i].texture.update(im)
        else:sprites[i].texture=ImageTexture.create_from_image(im)
        var x:float=480.+(float(i)-.5)*distance*SCALE
        sprites[i].position=Vector2(x,414.-(219.-135.)*SCALE/3.)
    distance_label.text="Дистанция %.1f  "%distance
    status.text="A: %d HP · %d попаданий     B: %d HP · %d попаданий     Тик: %d"%[hp[0],hits[0],hp[1],hits[1],ticks]
    queue_redraw()

func _draw()->void:
    draw_line(Vector2(28,414),Vector2(932,414),Color("#73858e"),1.)
func _process(delta:float)->void:
    if manual or paused or players.size()!=2:return
    clock+=minf(delta,.1)
    while clock>=1./60.:
        advance()
        clock-=1./60.
func _unhandled_input(e:InputEvent)->void:
    if e is InputEventKey and e.pressed and not e.echo:
        match UI.physical_key(e):
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_F:queue_attack(0)
            KEY_K:queue_attack(1)
            KEY_SPACE:paused=not paused
            KEY_R:reset()
