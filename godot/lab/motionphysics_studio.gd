extends Node2D
const Controller=preload("res://lab/motionphysics_controller.gd")
const Common=preload("res://lab/ragdoll_common_099c.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const UI=preload("res://lab/ui_ru.gd")
const CFG={"width":640,"height":360,"origin":[460,270],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e]]}
var controller=Controller.new()
var body=Body.new(2)
var raster
var canvas:TextureRect
var status:Label
var details:Label
var profile_select:OptionButton
var target_select:OptionButton
var direction_select:OptionButton
var material_select:OptionButton
var passes_select:OptionButton
var power:SpinBox
var accent:SpinBox
var hold:SpinBox
var release:SpinBox
var motor:SpinBox
var hitstop:SpinBox
var partial:CheckBox
var pause_button:Button
var hit_button:Button
var paused:bool=false
var manual:bool=false
var accumulator:float=0.
var last_ok:bool=false
var floor_screen:float=0.
var camera_x:float=460.
var camera_y:float=270.
var notice:String=""
var last_step_us:int=0

func _ready()->void:
    build_ui()
    if not ClassDB.class_exists("MotionPhysics099D") or not ClassDB.class_exists("PixelFXBodyRaster"):
        status.text="Нативные модули не установлены."
        details.text="Выполни native_cpp/build.py, затем native_cpp/build_motionphysics.py.\nHybrid и остальные инструменты доступны через меню."
        hit_button.disabled=true
        return
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    reset()

func label_at(text:String,at:Vector2)->Label:
    var l:=Label.new()
    l.text=text
    l.position=at
    add_child(l)
    return l

func button(parent:Control,text:String,fn:Callable)->Button:
    var b:=Button.new()
    b.text=text
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    b.focus_mode=Control.FOCUS_NONE
    parent.add_child(b)
    b.pressed.connect(fn)
    return b

func row_of(panel:VBoxContainer,text:String)->HBoxContainer:
    var row:=HBoxContainer.new()
    panel.add_child(row)
    var l:=Label.new()
    l.text=text
    l.custom_minimum_size.x=112.
    l.add_theme_font_size_override("font_size",12)
    row.add_child(l)
    return row

func choice(panel:VBoxContainer,text:String,items:Array,selected:int=0)->OptionButton:
    var row:=row_of(panel,text)
    var o:=OptionButton.new()
    o.fit_to_longest_item=false
    o.clip_text=true
    o.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    for item in items:o.add_item(item)
    o.select(selected)
    row.add_child(o)
    return o

func number(panel:VBoxContainer,text:String,lo:float,hi:float,inc:float,value:float)->SpinBox:
    var row:=row_of(panel,text)
    var s:=SpinBox.new()
    s.min_value=lo
    s.max_value=hi
    s.step=inc
    s.value=value
    s.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(s)
    return s

func build_ui()->void:
    label_at("LAB 1.0 RC1  /  Box2D · физика попаданий",Vector2(22,16)).add_theme_font_size_override("font_size",22)
    var back:=Button.new()
    back.text="Esc / Меню"
    back.position=Vector2(818,15)
    back.size=Vector2(120,34)
    add_child(back)
    back.pressed.connect(func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    canvas=TextureRect.new()
    canvas.position=Vector2(22,66)
    canvas.size=Vector2(640,360)
    canvas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(canvas)
    status=label_at("",Vector2(22,438))
    details=label_at("",Vector2(22,466))
    details.add_theme_font_size_override("font_size",12)
    var panel:=VBoxContainer.new()
    panel.position=Vector2(680,62)
    panel.size=Vector2(260,470)
    panel.add_theme_constant_override("separation",3)
    var theme0:=Theme.new()
    theme0.default_font_size=12
    panel.theme=theme0
    add_child(panel)
    profile_select=choice(panel,"Профиль",["A · Умеренный","B · Сильный","C · Экстремальный"],1)
    target_select=choice(panel,"Сегмент",["Таз","Грудь","Голова","Кисть (ближ.)","Бедро (ближ.)"])
    direction_select=choice(panel,"Импульс",["← Влево","→ Вправо","↑ Вверх","↓ Вниз"])
    power=number(panel,"Сила ×",.1,2.,.05,1.)
    accent=number(panel,"Акцент ×",0.,2.,.05,1.)
    hold=number(panel,"Удержание, с",.05,.6,.01,.30)
    release=number(panel,"Ослабление, с",.05,.5,.01,.19)
    motor=number(panel,"Мотор 0…1",0.,1.,.05,1.)
    hitstop=number(panel,"Hitstop, тики",0.,12.,1.,4.)
    material_select=choice(panel,"Поверхность",["Контроль 0.99","Скольжение 0.99c"],1)
    passes_select=choice(panel,"Подшаги Box2D",["8","12","16"])
    partial=CheckBox.new()
    partial.text="Фиксировать таз и ноги"
    panel.add_child(partial)
    hit_button=button(panel,"H / Применить импульс",apply_hit)
    var row:=HBoxContainer.new()
    panel.add_child(row)
    pause_button=button(row,"Пауза",toggle_pause)
    button(row,"→ Тик",single_step)
    button(row,"R Сброс",reset)
    var hint:=Label.new()
    hint.text="1/2/3 — пресеты; параметры считываются\nпри ударе. Поверхность/подшаги — сброс."
    panel.add_child(hint)
    profile_select.item_selected.connect(set_profile)
    material_select.item_selected.connect(func(_i:int):reset())
    passes_select.item_selected.connect(func(_i:int):reset())
    partial.toggled.connect(set_partial)

func set_profile(value:int)->void:
    profile_select.select(value)
    var p:Dictionary=Controller.PROFILES[value]
    accent.value=p.accent
    hold.value=p.hold
    release.value=p.release
    motor.value=p.motor
    hitstop.value=p.hitstop
    # Compare presets from the same guard; custom controls apply at the next hit.
    reset()

func parameters()->Dictionary:
    return {"accent":accent.value,"hold":hold.value,"release":release.value,"motor":motor.value,"hitstop":int(hitstop.value)}

func reset()->void:
    if raster==null:return
    if not controller.setup(profile_select.selected,int(passes_select.get_item_text(passes_select.selected)),material_select.selected):
        last_ok=false
        status.text="Не удалось создать мир Box2D"
        return
    if partial.button_pressed and not controller.set_pinned(true):
        last_ok=false
        status.text="Ошибка кинематической опоры"
        return
    camera_x=460.
    camera_y=270.
    last_step_us=0
    accumulator=0.
    notice=""
    last_ok=render_frame()

func set_partial(value:bool)->void:
    if controller.world==null:return
    if not controller.set_pinned(value):
        notice="Ошибка смены физического управления"
    elif value and target_select.selected in [0,4]:
        target_select.select(3)
    last_ok=render_frame()

func apply_hit()->void:
    if controller.world==null:return
    var id:String=["hips","chest","head","hand_near","thigh_near"][target_select.selected]
    var direction:Vector2=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN][direction_select.selected]
    notice="" if controller.hit(id,direction,power.value,parameters()) else "Импульс отклонён: сегмент закреплён или параметры неверны."
    last_ok=render_frame()

func toggle_pause()->void:
    paused=not paused
    pause_button.text="Пуск" if paused else "Пауза"
func single_step()->void:
    if paused:advance_tick()

func advance_tick()->void:
    if controller.world==null:return
    var start:int=Time.get_ticks_usec()
    if not controller.step() or not controller.step():
        last_ok=false
        paused=true
        status.text="Ошибка шага Box2D"
        return
    last_step_us=Time.get_ticks_usec()-start
    last_ok=render_frame()

func render_frame()->bool:
    if raster==null or controller.world==null:return false
    var pose:Dictionary=controller.pose()
    var rig=controller.model.rig
    var parts:Array=body.make(rig.points,pose.angles,rig.rotations.head)
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
    var cfg:Dictionary=CFG.duplicate(true)
    var min_pt:=Vector2(INF,INF)
    var max_pt:=Vector2(-INF,-INF)
    for point in rig.points.values():
        var p:Vector2=point
        min_pt=Vector2(minf(min_pt.x,p.x),minf(min_pt.y,p.y))
        max_pt=Vector2(maxf(max_pt.x,p.x),maxf(max_pt.y,p.y))
    camera_x=clampf(camera_x,40.-min_pt.x*3.,600.-max_pt.x*3.)
    camera_y=clampf(camera_y,40.-min_pt.y*3.,320.-max_pt.y*3.)
    cfg.origin=[camera_x,camera_y]
    floor_screen=camera_y+controller.model.floor_y*3.
    var result:Dictionary=raster.render(cfg,parts)
    if not result.get("ok",false):
        status.text="Ошибка PixelFXBodyRaster: "+str(result)
        return false
    var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    if canvas.texture==null:canvas.texture=ImageTexture.create_from_image(im)
    else:canvas.texture.update(im)
    var m:Dictionary=Common.validate(controller.model)
    var com:Vector2=controller.model.center_of_mass()
    status.text="Тик %d · COM (%.1f, %.1f) · физика %d мкс / 60 Гц"%[controller.tick,com.x,com.y,last_step_us]
    details.text="Якорь %.3f · предел %.2f° · пол %.3f · FK %.3f"%[m.anchor,m.angle_error_deg,m.penetration,controller.model.pose_error]
    details.text+="\n"+("Таз/ноги закреплены" if controller.pinned else "Все сегменты динамические")+" · импульсов "+str(controller.event_count)
    details.text+="\n"+(notice if notice!="" else "Тестовый импульс · плоский пол · без самоколлизии и контакта бойцов.")
    queue_redraw()
    return true

func _process(delta:float)->void:
    if manual or paused or controller.world==null:return
    accumulator+=minf(delta,.1)
    while accumulator>=1./60.:
        advance_tick()
        accumulator-=1./60.

func _draw()->void:
    draw_rect(Rect2(0,0,960,540),Color("#17232e"))
    draw_rect(Rect2(22,66,640,360),Color("#34424d"))
    if floor_screen>=0. and floor_screen<=360.:
        var y:float=66.+floor_screen
        draw_line(Vector2(22,y),Vector2(662,y),Color("#8296a0"),1.)
        var shift:float=fposmod(camera_x,30.)
        for i in 22:
            var x:float=22.+shift+30.*i
            if x<662.:draw_line(Vector2(x,y),Vector2(x,y+5.),Color("#8296a0"),1.)

func _unhandled_input(e:InputEvent)->void:
    if e is InputEventKey and e.pressed and not e.echo:
        match UI.physical_key(e):
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_SPACE:toggle_pause()
            KEY_RIGHT:single_step()
            KEY_R:reset()
            KEY_H:apply_hit()
            KEY_1:set_profile(0)
            KEY_2:set_profile(1)
            KEY_3:set_profile(2)
