extends Node2D
## Integration workspace. The accepted kernel remains the gameplay pose source.
## 092 is a separate experiment in this UI, not a competing integrated runtime.
const Body=preload("res://lab/body_ankle_069.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const Cloth=preload("res://lab/secondary_motion_074.gd")
const Reaction=preload("res://lab/impact_reactions_092.gd")
const UI=preload("res://lab/ui_ru.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const CHANNELS=["chest","head","shoulder_turn","shoulder_near","elbow_near","shoulder_far","elbow_far"]
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var player
var reaction
var raster
var body=Body.new(2)
var cloth
var rig
var run_clip:Dictionary
var attack_clip:Dictionary
var bank:Dictionary
var mode:int=0
var cloth_mode:int=0
var target_speed:float=1.
var pending_action:String=""
var pending_impulse:float=0.
var pending_hits:Array=[]
var hit_id:int=0
var accumulator:float=0.
var paused:bool=false
var manual:bool=false
var status:Label
var details:Label
var canvas:TextureRect
var pause_button:Button
var mode_select:OptionButton
var cloth_select:OptionButton
var wind_slider:HSlider
var frame_tick:int=0
var last_pose:Dictionary={}
var last_travel:float=0.
var last_ok:bool=false
var last_render_us:int=0

func _ready()->void:
    build_ui()
    if not ClassDB.class_exists("PixelFXBodyRaster"):
        status.text="Нет нативного расширения PixelFXBodyRaster"
        details.text="Собери native_cpp/build.py для Godot 4.4.1.\nСтарые инструменты доступны через меню."
        return
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    run_clip=read_clip("run053a_C")
    attack_clip=read_clip("combo052a2_B")
    var kick:Dictionary=read_clip("highkick051c2_C")
    if run_clip.is_empty() or attack_clip.is_empty() or kick.is_empty():
        status.text="Отсутствуют исходные клипы Lab"
        raster=null
        return
    bank={"jab":Motion.compile(attack_clip,0,38,CHANNELS,60),"cross":Motion.compile(attack_clip,23,45,CHANNELS,60),"kick":Motion.compile(kick,23,53,CHANNELS,60,Body.make_rig(),{"far":[23,33,40,53]})}
    reset()

func read_clip(name:String)->Dictionary:
    var data=JSON.parse_string(FileAccess.get_file_as_string(FIX+name+".json"))
    if not data is Dictionary:return {}
    return data.payload.clip

func build_ui()->void:
    var title=Label.new()
    title.position=Vector2(22,14)
    title.text="LAB 1.0 RC1   /   Гибридное движение"
    title.add_theme_font_size_override("font_size",23)
    add_child(title)
    var back=Button.new()
    back.text="Esc / Меню"
    back.position=Vector2(818,15)
    back.size=Vector2(120,34)
    back.pressed.connect(func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    add_child(back)
    canvas=TextureRect.new()
    canvas.position=Vector2(22,66)
    canvas.size=Vector2(640,360)
    canvas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(canvas)
    status=Label.new()
    status.position=Vector2(22,440)
    status.size=Vector2(640,28)
    add_child(status)
    details=Label.new()
    details.position=Vector2(22,470)
    details.size=Vector2(640,58)
    details.add_theme_font_size_override("font_size",12)
    add_child(details)
    var panel=VBoxContainer.new()
    panel.position=Vector2(684,64)
    panel.size=Vector2(254,464)
    panel.add_theme_constant_override("separation",6)
    add_child(panel)
    mode_select=OptionButton.new()
    mode_select.add_item("Astra Hybrid 0.91")
    mode_select.add_item("Реакции 0.92 C (отдельно)")
    panel.add_child(mode_select)
    mode_select.item_selected.connect(set_mode)
    var controls=HBoxContainer.new()
    panel.add_child(controls)
    button(controls,"Стоп",func():target_speed=0.)
    button(controls,"Шаг",func():target_speed=1.)
    button(controls,"Бег",func():target_speed=1.85)
    var attacks=HBoxContainer.new()
    panel.add_child(attacks)
    button(attacks,"F Джеб",func():queue_action("jab"))
    button(attacks,"G Кросс",func():queue_action("cross"))
    button(attacks,"K Нога",func():queue_action("kick"))
    button(panel,"J / Удар в голову",func():queue_hit("HEAD",.85,false))
    button(panel,"B / Удар в корпус",func():queue_hit("BODY",.85,false))
    button(panel,"N / Сильный удар",func():queue_hit("HEAD",1.45,true))
    var label=Label.new()
    label.text="Декоративная ткань (120 Гц)"
    panel.add_child(label)
    cloth_select=OptionButton.new()
    cloth_select.add_item("Без ткани")
    cloth_select.add_item("B / пространственный ветер")
    cloth_select.add_item("C / мягкий материал")
    panel.add_child(cloth_select)
    cloth_select.item_selected.connect(set_cloth)
    var wind_label=Label.new()
    wind_label.text="Ветер (−180 … +180)"
    panel.add_child(wind_label)
    wind_slider=HSlider.new()
    wind_slider.min_value=-180.
    wind_slider.max_value=180.
    wind_slider.step=5.
    wind_slider.custom_minimum_size=Vector2(0,22)
    panel.add_child(wind_slider)
    pause_button=button(panel,"Space / Пауза",toggle_pause)
    button(panel,"→ / Один тик",func():
        if paused:advance_tick())
    button(panel,"R / Сброс",reset)
    var hint=Label.new()
    hint.text="1 стоп · 2 шаг · 3 бег\nF/G/K атаки · J/B/N реакции\nАтаки в Hybrid, шаг в 0.92."
    hint.add_theme_font_size_override("font_size",12)
    panel.add_child(hint)

func button(parent:Control,title:String,fn:Callable)->Button:
    var b=Button.new()
    b.text=title
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    b.focus_mode=Control.FOCUS_NONE
    parent.add_child(b)
    b.pressed.connect(fn)
    return b

func set_mode(value:int)->void:
    mode=value
    mode_select.select(value)
    reset()

func set_cloth(value:int)->void:
    cloth_mode=value
    cloth_select.select(value)
    cloth=null
    if raster!=null and not last_pose.is_empty():
        update_cloth(last_travel,false)
        render_frame()

func toggle_pause()->void:
    paused=not paused
    pause_button.text="Space / Продолжить" if paused else "Space / Пауза"

func reset()->void:
    if raster==null:return
    rig=Body.make_rig()
    if mode==0:
        player=Kernel.new(rig,run_clip,bank,bank.jab.frames[0],60)
        last_pose=player.final_pose
        reaction=null
    else:
        reaction=Reaction.new(rig,attack_clip.keys[0].pose,2)
        player=null
        last_pose=reaction.base
        rig.evaluate(last_pose)
    pending_action=""
    pending_impulse=0.
    pending_hits.clear()
    hit_id=0
    accumulator=0.
    frame_tick=0
    target_speed=1.
    last_travel=0.
    cloth=null
    update_cloth(0.,false)
    render_frame()

func queue_action(action:String)->void:
    if mode==0:pending_action=action

func queue_hit(zone:String,power:float,finisher:bool)->void:
    if mode==0:
        # Only Astra's accepted simple chest impulse in this mode.
        pending_impulse+=(-140. if zone=="HEAD" else 140.)*power
    else:pending_hits.append([zone,power,finisher])

func advance_tick()->void:
    if raster==null:return
    if mode==0:
        var cmd={"speed":target_speed,"impulse":pending_impulse}
        if not pending_action.is_empty():cmd.action=pending_action
        player.step(cmd)
        last_pose=player.final_pose
        last_travel=player.gait.travel
    else:
        for event in pending_hits:
            hit_id+=1
            if reaction.hit(hit_id,event[0],-1.,event[1]) and event[2]:reaction.permit_recovery_step(-1.)
        var sample:Dictionary=reaction.step()
        last_pose=sample.pose
        last_travel=0.
    pending_action=""
    pending_impulse=0.
    pending_hits.clear()
    frame_tick+=1
    update_cloth(last_travel,true)
    render_frame()

func update_cloth(travel:float,advance:bool)->void:
    if cloth_mode==0:return
    var chest:Vector2=rig.point("chest")+Vector2.RIGHT*travel
    var head:Vector2=rig.point("head")+Vector2.RIGHT*travel
    var n:Vector2=chest.lerp(head,.36)
    var anchor:=Vector3(n.x+1.1,n.y,2.7)
    if cloth==null:
        cloth=Cloth.new()
        cloth.configure(cloth_mode)
        cloth.reset(anchor)
    cloth.set_anchor(anchor)
    cloth.collisions=[[Vector3(chest.x,chest.y+4.,0.),Vector3(4.8,7.8,3.35)],[Vector3(head.x,head.y,0.),Vector3(3.9,4.4,3.25)]]
    if advance:
        for sub in 2:cloth.step(wind_slider.value,false)

func render_frame()->void:
    var parts:Array=body.make(rig.points,last_pose.angles,rig.rotations.head)
    if mode==0:Depth.apply(parts,player.style)
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
    if cloth!=null:
        var first:int=parts.size()
        cloth.triangles(parts,3)
        for i in range(first,parts.size()):
            for key in ["a","b","c"]:parts[i][key][0]-=last_travel
    var before:int=Time.get_ticks_usec()
    var result:Dictionary=raster.render(CFG,parts)
    last_render_us=Time.get_ticks_usec()-before
    last_ok=result.get("ok",false)
    if not last_ok:
        status.text="Ошибка растеризации: "+str(result)
        return
    var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    if canvas.texture==null:canvas.texture=ImageTexture.create_from_image(im)
    else:canvas.texture.update(im)
    if mode==0:
        status.text="Тик %d  ·  скорость %.2f  ·  действие %s  ·  путь %.1f"%[frame_tick,player.speed,player.action if player.action!="" else "локомоция",last_travel]
        details.text="Astra 0.91: единое ядро, 60 Гц; камера следует за персонажем.\nТорможение пока экспериментальное. Контакт двух бойцов не реализован."
    else:
        status.text="Тик %d  ·  попаданий %d  ·  шаг %s"%[frame_tick,reaction.seen.size(),"активен" if reaction.step_age>=0 else "нет"]
        details.text="0.92 C: отдельный стенд реакций с заданными импульсами.\nФинишер разрешает компенсирующий шаг, не отбрасывание."
    details.text+="\nРастеризация %d мкс · ткань %s (только визуальная)"%[last_render_us,["выкл","B","C"][cloth_mode]]
    queue_redraw()

func _process(delta:float)->void:
    if manual or paused or raster==null:return
    accumulator+=minf(delta,.1)
    while accumulator>=1./60.:
        advance_tick()
        accumulator-=1./60.

func _draw()->void:
    draw_rect(Rect2(0,0,960,540),Color("#17232e"))
    draw_rect(Rect2(22,66,640,360),Color("#34424d"))
    var shift:float=fposmod(last_travel*4.,32.)
    for i in 21:
        var x:float=22.+i*32.-shift
        if x>=22. and x<=662.:draw_line(Vector2(x,90),Vector2(x,358),Color("#3f505d"),1.)
    draw_line(Vector2(22,358),Vector2(662,358),Color("#8296a0"),1.)

func _unhandled_input(e:InputEvent)->void:
    if e is InputEventKey and e.pressed and not e.echo:
        match UI.physical_key(e):
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_1:target_speed=0.
            KEY_2:target_speed=1.
            KEY_3:target_speed=1.85
            KEY_F:queue_action("jab")
            KEY_G:queue_action("cross")
            KEY_K:queue_action("kick")
            KEY_J:queue_hit("HEAD",.85,false)
            KEY_B:queue_hit("BODY",.85,false)
            KEY_N:queue_hit("HEAD",1.45,true)
            KEY_SPACE:toggle_pause()
            KEY_RIGHT:
                if paused:advance_tick()
            KEY_R:reset()
