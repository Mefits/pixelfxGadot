extends Node2D
const Walk=preload("res://lab/walk_control.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const UI=preload("res://lab/ui_ru.gd")
const SCALE:float=5.
const ORIGIN=Vector2(480,413)
var walker
var held:Dictionary={}
var body=Body.new(2)
var raster
var sprite:Sprite2D
var status:Label
var state_label:Label
var accumulator:float=0.
var manual:bool=false
var last_ok:bool=false

func _ready()->void:
    label("СТЕНД УПРАВЛЕНИЯ / ХОДЬБА",Vector2(24,15),23)
    label("A / ← — назад     D / → — вперёд     R — сброс     Esc — меню",Vector2(24,56),15)
    label("Персонаж всегда смотрит вправо. Отпусти клавиши для остановки.",Vector2(24,83),13)
    var back:=Button.new()
    back.text="Меню / Esc"
    back.position=Vector2(812,15)
    back.size=Vector2(124,34)
    back.focus_mode=Control.FOCUS_NONE
    back.pressed.connect(func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    add_child(back)
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale=Vector2.ONE*SCALE/3.
    add_child(sprite)
    state_label=label("",Vector2(24,454),18)
    status=label("",Vector2(24,486),13)
    label("Тест: обратный ход временно использует тот же цикл в обратном направлении.",Vector2(24,514),12)
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")
    reset()

func label(value:String,at:Vector2,font_size:int)->Label:
    var l:=Label.new()
    l.position=at
    l.text=value
    l.add_theme_font_size_override("font_size",font_size)
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(l)
    return l

func reset()->void:
    held.clear()
    walker=Walk.new()
    accumulator=0.
    render_frame()

func command()->int:
    var left:bool=held.get(KEY_A,false) or held.get(KEY_LEFT,false)
    var right:bool=held.get(KEY_D,false) or held.get(KEY_RIGHT,false)
    return int(right)-int(left)

func advance()->void:
    walker.step(command())
    render_frame()

func render_frame()->void:
    state_label.text="Действие: "+["Ходьба назад","Стойка","Ходьба вперёд"][walker.direction+1]
    status.text="Положение: %.1f    ·    направление взгляда: вправо    ·    %s"%[walker.x,walker.action_name()]
    last_ok=false
    if raster==null:
        status.text="Нет нативного тела. Запусти полный пакет START_LAB.bat."
        return
    var parts:Array=body.make(walker.rig.points,walker.pose.angles,walker.rig.rotations.head)
    Depth.apply(parts,0.)
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
    var result:Dictionary=raster.render(Studio.CFG,parts)
    if not result.get("ok",false):
        status.text="Ошибка отрисовки"
        return
    var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
    else:sprite.texture.update(im)
    sprite.position=ORIGIN+Vector2.RIGHT*walker.x*SCALE-Vector2(240,219)*SCALE/3.
    last_ok=true

func _process(delta:float)->void:
    if manual or walker==null:return
    accumulator+=minf(delta,.1)
    var changed:bool=false
    while accumulator>=1./60.:
        if command()!=0 or walker.activity>0. or walker.direction!=0:
            walker.step(command())
            changed=true
        accumulator-=1./60.
    if changed:render_frame()

func _input(event:InputEvent)->void:
    if not event is InputEventKey:return
    var key=UI.physical_key(event)
    if key in [KEY_A,KEY_D,KEY_LEFT,KEY_RIGHT]:
        held[key]=event.pressed
        get_viewport().set_input_as_handled()
    elif event.pressed and not event.echo:
        if key==KEY_R:reset()
        elif key==KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")

func _notification(what:int)->void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:held.clear()

func _draw()->void:
    draw_rect(Rect2(0,0,960,540),Color("#17232e"))
    draw_rect(Rect2(20,114,920,322),Color("#34424d"))
    for i in 23:
        var x:float=40.+40.*i
        draw_line(Vector2(x,114),Vector2(x,413),Color("#40515d"))
    draw_line(Vector2(20,413),Vector2(940,413),Color("#a0adb8"),2.)
    draw_line(Vector2(480,413),Vector2(480,430),Color("#a0adb8"),2.)
