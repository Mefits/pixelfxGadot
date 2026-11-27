extends Node2D
const Jump=preload("res://lab/jump_control.gd")
const Polish=preload("res://lab/jump_polish_panel.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Training=preload("res://lab/training_control.gd")
const Walk=preload("res://lab/walk_control.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Profile=preload("res://lab/fighter_profile.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const UI=preload("res://lab/ui_ru.gd")
const SCALE:float=4.5
const STAGE_SIZE=Vector2(1920,1140)
const ARENA=Rect2(20,114,1880,935)
const ORIGIN=Vector2(960,1025)
const ARENA_LIMIT:float=165.
var walker
var training
var attack_held:Dictionary={}
var held:Dictionary={}
var jump_held:bool=false
const view_scale:float=SCALE

var body
var raster
var sprite:Sprite2D
var status:Label
var state_label:Label
var manual:bool=false
var last_ok:bool=false
var last_image:Image
var foot_debug:bool=false
var foot_labels:Array[Label]=[]
var polish
var paused:bool=false
var playback_speed:float=1.
var playback_credit:float=0.
var trajectory:PackedVector2Array=PackedVector2Array()
var trace_running:bool=false
var jump_frame:int=0
var jump_total:int=0
var measured_peak:float=0.
var impulse_index:int=-1

func _ready()->void:
    # Fit only on window resize, never on character movement or jump.
    get_viewport().size_changed.connect(fit_stage)
    fit_stage()
    label("БОЕВОЙ СТЕНД / ТРЕНИРОВКА",Vector2(24,15),23)
    label("A / ← назад   D / → вперёд   Shift — бег   Space — прыжок / второй импульс   1 — атака   R — сброс",Vector2(24,56),15)
    label("Нажми 1 до трёх раз: 1 → 1 → 1. Удержание не повторяет.",Vector2(24,83),13)
    var back:=Button.new()
    back.text="Меню / Esc"
    back.position=Vector2(1772,15)
    back.size=Vector2(124,34)
    back.focus_mode=Control.FOCUS_NONE
    back.pressed.connect(func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    add_child(back)
    var tools:=Button.new()
    tools.text="Прыжок / F3"
    tools.position=Vector2(1600,15)
    tools.size=Vector2(158,34)
    tools.focus_mode=Control.FOCUS_NONE
    tools.pressed.connect(toggle_polish)
    add_child(tools)
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale=Vector2.ONE*SCALE/3.
    add_child(sprite)
    state_label=label("",Vector2(24,1061),18)
    status=label("",Vector2(24,1092),13)
    label("F2: метки стоп · F3: полировка · P: пауза · N: кадр +1 · фиксированная арена.",Vector2(24,1118),12)
    for i in 2:
        var mark:Label=label("БЛ" if i==0 else "ДЛ",Vector2.ZERO,15)
        mark.add_theme_color_override("font_color",Color("#ffcc65") if i==0 else Color("#8ed6ff"))
        mark.z_index=10
        mark.hide()
        foot_labels.append(mark)
    polish=Polish.new()
    polish.position=Vector2(32,125)
    polish.z_index=20
    add_child(polish)
    polish.jump_requested.connect(start_jump)
    polish.pause_requested.connect(toggle_pause)
    polish.step_requested.connect(step_once)
    polish.speed_changed.connect(set_playback_speed)
    polish.trace_changed.connect(queue_redraw)
    polish.hide()
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")
    reset()

func fit_stage()->void:
    var available:Vector2=get_viewport_rect().size
    var factor:float=minf(available.x/STAGE_SIZE.x,available.y/STAGE_SIZE.y)
    scale=Vector2.ONE*factor
    position=(available-STAGE_SIZE*factor)*.5

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
    attack_held.clear()
    jump_held=false
    trajectory.clear()
    trace_running=false
    jump_frame=0
    jump_total=0
    measured_peak=0.
    impulse_index=-1
    playback_credit=0.
    training=Training.new()
    walker=training.walker
    walker.travel_limit=ARENA_LIMIT
    body=Profile.make_body(walker.profile)
    render_frame()

func command()->int:
    var left:bool=held.get(KEY_A,false) or held.get(KEY_LEFT,false)
    var right:bool=held.get(KEY_D,false) or held.get(KEY_RIGHT,false)
    return int(right)-int(left)

func start_jump(direction:int)->void:
    if training.active!=0:return
    if training.jump.state==0:
        training.jump.configure(polish.settings())
        if training.press_jump(direction):
            begin_trace()
            render_frame()
    elif training.jump.can_second() and training.press_jump(direction):
        impulse_index=trajectory.size()-1
        jump_total=jump_frame+training.jump.second_ticks
        render_frame()

func begin_trace()->void:
    trajectory.clear()
    trajectory.append(Vector2(walker.x,-training.jump.altitude))
    trace_running=true
    jump_frame=0
    jump_total=Jump.PREP_TICKS+training.jump.flight_ticks
    measured_peak=0.
    impulse_index=-1

func advance()->void:
    var jumping:bool=training.jump.state!=0
    if jumping and not trace_running:begin_trace()
    training.step(command(),bool(held.get(KEY_SHIFT,false)))
    if jumping:
        trajectory.append(Vector2(walker.x,-training.jump.altitude))
        jump_frame+=1
        measured_peak=maxf(measured_peak,training.jump.altitude)
        if training.jump.state==0:trace_running=false
    render_frame()

func toggle_polish()->void:
    polish.visible=not polish.visible
    queue_redraw()

func set_playback_speed(value:float)->void:
    playback_speed=value
    playback_credit=0.
    render_frame()

func toggle_pause()->void:
    paused=not paused
    playback_credit=0.
    render_frame()

func step_once()->void:
    paused=true
    playback_credit=0.
    advance()

func jump_phase()->String:
    if training.jump.state==1:return "Подготовка / толчок"
    if training.jump.state==0:return "Завершён" if jump_frame>0 else "Готов к прыжку"
    if training.jump.second_used:
        var v:float=float(training.jump.age)/60.
        if v<training.jump.second_time*.20:return "Воздушный толчок"
        return "Второй подъём" if v<training.jump.second_vy/training.jump.gravity else "Второй спуск"
    var u:float=float(training.jump.age)/training.jump.flight_ticks
    if u<.18:return "Взлёт"
    if u<.42:return "Подъём"
    if u<.62:return "Вершина"
    return "Спуск"

func render_frame()->void:
    # Altitude translates only the actor; the arena and camera stay fixed.
    var altitude:float=training.jump.altitude
    state_label.text="Действие: "+("Остановка" if walker.direction==0 and walker.activity>0. else ("Idle" if walker.action_name()=="walk_breathe" else ["Ходьба назад","Стойка","Ходьба вперёд"][walker.direction+1]))
    if walker.sprint_active:
        state_label.text="Бег" if held.get(KEY_SHIFT,false) and command()==walker.direction else "Торможение / переход"
        state_label.text+=" · "+("вперёд" if walker.direction>0 else "назад")
    if walker.action_name()=="walk_breathe" and training.active==0:
        var near_percent:int=roundi(float(walker.support_load[0])*100.)
        var lead:String="ближняя" if walker.guard_lead==0 else "дальняя"
        state_label.text="Idle %.2f с · Впереди: %s · Опора ближ./дальн. %d/%d%%"%[walker.idle_time(),lead,near_percent,100-near_percent]
    if training.active!=0:
        var limb:String=("Нога" if training.strike_anchor.begins_with("foot_") else "Рука")+" "+("дальняя" if training.strike_anchor.ends_with("_far") else "ближняя")
        state_label.text=("Подготовка" if training.preparation_age<int(training.binding.prepare_ticks) else "Удар")+" %d · %s · В буфере: %d"%[training.active,limb,training.queued]
        if not training.landing.is_empty() and training.age>int(training.landing.start):
            state_label.text="Приземление · %d/%d"%[training.age,training.release_tick]
    if training.jump.state!=0:
        state_label.text="Прыжок %d/2 · "%[2 if training.jump.second_used else 1]+jump_phase()+" · Высота %.1f"%altitude
    var actual_toes:Array=Motion.toes(walker.rig,walker.pose)
    var actual_lead:int=Walk.lead_of(actual_toes,walker.guard_lead)
    if training.active!=0:
        state_label.text+=" · Впереди: "+("ближняя" if actual_lead==0 else "дальняя")+" · "+str(training.binding.role)
    for i in 2:
        foot_labels[i].visible=foot_debug
        foot_labels[i].position=ORIGIN+Vector2(walker.x,-altitude)*view_scale+Vector2(actual_toes[i])*view_scale+Vector2(-10,3)
    status.text="Попадания: %d   Промахи: %d   Последнее комбо: %d   ·   %s"%[training.hits,training.misses,training.last_chain,training.result]
    var speed:float=training.jump.vx if training.jump.state==2 else (training.jump.inherited_speed if training.jump.state==1 else walker.ground_speed)
    state_label.text+=" · Vx %+.1f"%speed
    if paused:state_label.text+=" · ПАУЗА"
    if playback_speed!=1.:state_label.text+=" · %.2f×"%playback_speed
    var description:String="%s · %d/%d\nПик: %.2f роста"%[jump_phase(),jump_frame,jump_total,measured_peak/maxf(1.,training.jump.body_height)]
    polish.set_status(paused,training.active==0 and training.jump.state==0,description,training.jump.can_second())
    queue_redraw()
    last_ok=false
    if raster==null:
        status.text="Нет нативного тела. Проверь Godot 4.4.1 x64 и DLL в addons."
        return
    var parts:Array=body.make(walker.rig.points,walker.pose.angles,walker.rig.rotations.head)
    var run_weight:float=clampf((absf(walker.ground_speed)/60.-1.)/.85,0.,1.) if walker.sprint_active and walker.direction>0 else 0.
    Depth.apply(parts,run_weight)
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
    var result:Dictionary=raster.render(Studio.CFG,parts)
    if not result.get("ok",false):
        status.text="Ошибка отрисовки"
        return
    var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    last_image=im
    # Publish a fresh image for T (also avoids relying on in-place texture
    # uploads on the affected compatibility-renderer setup).
    sprite.texture=ImageTexture.create_from_image(im)
    sprite.scale=Vector2.ONE*view_scale/3.
    sprite.position=ORIGIN+Vector2(walker.x,-altitude)*view_scale-Vector2(240,219)*view_scale/3.
    last_ok=true

func _physics_process(_delta:float)->void:
    if manual or paused or walker==null:return
    playback_credit+=playback_speed
    if playback_credit>=1.-.000001:
        playback_credit=maxf(0.,playback_credit-1.)
        advance()

func _input(event:InputEvent)->void:
    if not event is InputEventKey:return
    var key=UI.physical_key(event)
    if key in [KEY_A,KEY_D,KEY_LEFT,KEY_RIGHT,KEY_SHIFT]:
        held[key]=event.pressed
        get_viewport().set_input_as_handled()
    elif key==KEY_SPACE:
        if event.pressed and not event.echo and not jump_held:start_jump(command())
        jump_held=event.pressed
        get_viewport().set_input_as_handled()
    elif key==KEY_1:
        if event.pressed and not event.echo and not attack_held.get(key,false):training.press(1)
        attack_held[key]=event.pressed
        get_viewport().set_input_as_handled()
    elif event.pressed and not event.echo:
        if key==KEY_R:reset()
        elif key==KEY_F3:toggle_polish()
        elif key==KEY_P:toggle_pause()
        elif key==KEY_N:step_once()
        elif key==KEY_F2:
            foot_debug=not foot_debug
            render_frame()
        elif key==KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")

func _notification(what:int)->void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        held.clear()
        attack_held.clear()
        jump_held=false

func _draw()->void:
    draw_rect(Rect2(Vector2.ZERO,STAGE_SIZE),Color("#17232e"))
    draw_rect(ARENA,Color("#34424d"))
    var grid_count:int=ceili((ARENA.size.x*.5)/(8.*view_scale))
    for i in range(-grid_count,grid_count+1):
        var x:float=ORIGIN.x+8.*i*view_scale
        if x>=ARENA.position.x and x<=ARENA.end.x:draw_line(Vector2(x,ARENA.position.y),Vector2(x,ORIGIN.y),Color("#40515d"))
    draw_line(Vector2(ARENA.position.x,ORIGIN.y),Vector2(ARENA.end.x,ORIGIN.y),Color("#a0adb8"),2.)
    draw_line(ORIGIN,ORIGIN+Vector2(0,17),Color("#a0adb8"),2.)

    if polish!=null and polish.visible and polish.trace_box.button_pressed:
        draw_jump_trace()
    if training:
        if training.jump.state==2:
            draw_ellipse_shadow()
        var center:Vector2=ORIGIN+Vector2(Training.BAG_X*view_scale,Training.BAG_TOP*view_scale)
        var shift:float=training.bag_sway*view_scale
        draw_line(center+Vector2(0,-13.*view_scale),center+Vector2(shift,0),Color("#85929e"),3.)
        var top:Vector2=center+Vector2(shift,0)
        var bottom:Vector2=top+Vector2(0,(Training.BAG_BOTTOM-Training.BAG_TOP)*view_scale)
        var fill:Color=Color("#b76a50") if training.hit_flash==0 else Color("#f4c47c")
        draw_line(top,bottom,Color("#20252c"),Training.BAG_RADIUS*view_scale*2.+4.,true)
        draw_circle(top,Training.BAG_RADIUS*view_scale+2.,Color("#20252c"))
        draw_circle(bottom,Training.BAG_RADIUS*view_scale+2.,Color("#20252c"))
        draw_line(top,bottom,fill,Training.BAG_RADIUS*view_scale*2.,true)
        draw_circle(top,Training.BAG_RADIUS*view_scale,fill)
        draw_circle(bottom,Training.BAG_RADIUS*view_scale,fill)
        draw_line(top+Vector2(-2.4*view_scale,0),bottom+Vector2(-2.4*view_scale,0),Color("#ffffff22"),3.)

func draw_ellipse_shadow()->void:
    var center:Vector2=ORIGIN+Vector2.RIGHT*walker.x*view_scale
    var width:float=9.*view_scale
    draw_line(center-Vector2(width*.5,0),center+Vector2(width*.5,0),Color(0.1,0.14,0.18,0.55),3.,true)

func draw_jump_trace()->void:
    if trajectory.is_empty():return
    var points:=PackedVector2Array()
    for sample in trajectory:points.append(ORIGIN+sample*view_scale)
    if points.size()>1:draw_polyline(points,Color("#7cdbbf"),2.,true)
    for i in range(0,points.size(),6):draw_circle(points[i],3.5,Color("#7cdbbf"))
    draw_circle(points[points.size()-1],5.,Color("#e4fff5"))
    if impulse_index>=0 and impulse_index<points.size():
        draw_circle(points[impulse_index],8.,Color("#ffcc65"))
