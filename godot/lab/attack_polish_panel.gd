extends PanelContainer
const Tuning=preload("res://lab/attack_tuning.gd")
const SPEEDS=[1.,.5,.25,.1]
signal settings_changed
signal attack_requested(index:int)
signal pause_requested
signal step_requested
signal speed_changed(value:float)
signal trace_changed
signal repeat_changed(enabled:bool)
var profiles:Array=[Tuning.defaults(false),Tuning.defaults(true)]
var index:int=0
var updating:bool=false
var sliders:Dictionary={}
var values:Dictionary={}
var chooser:OptionButton
var leg:OptionButton
var speed_choice:OptionButton
var trace_box:CheckBox
var previous_trace_box:CheckBox
var pause_button:Button
var launch:Button
var repeat_button:Button
var repeat_delay:SpinBox
var stats:Label
var feedback:Label
var timing:Label

func _ready()->void:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("#18232ef5")
    style.set_corner_radius_all(8)
    style.content_margin_left=14.
    style.content_margin_right=14.
    style.content_margin_top=12.
    style.content_margin_bottom=12.
    add_theme_stylebox_override("panel",style)
    custom_minimum_size=Vector2(410,0)
    var col:=VBoxContainer.new()
    col.add_theme_constant_override("separation",4)
    add_child(col)
    caption(col,"ATTACK LAB / F4",22)
    caption(col,"Параметры фиксируются при начале атаки",14)
    chooser=OptionButton.new()
    chooser.focus_mode=Control.FOCUS_NONE
    chooser.add_item("K — удар пяткой")
    chooser.add_item("L — круговой (2.5D)")
    col.add_child(chooser)
    chooser.item_selected.connect(select_attack)
    slider(col,"prep_ticks","Подготовка · кадры",3.,20.,1.)
    slider(col,"strike_ticks","Выброс · кадры",2.,8.,1.)
    slider(col,"return_ticks","Возврат · кадры",5.,22.,1.)
    slider(col,"recovery_ticks","Восстановление · кадры",5.,25.,1.)
    timing=caption(col,"",15)
    col.add_child(HSeparator.new())
    slider(col,"reach_scale","Целевая амплитуда",.6,1.1,.05)
    slider(col,"pelvis_scale","Разворот таза",0.,1.5,.05)
    slider(col,"shoulder_scale","Разворот плеч",0.,1.5,.05)
    slider(col,"acceleration_scale","Акцент ускорения",.5,1.5,.05)
    leg=OptionButton.new()
    leg.focus_mode=Control.FOCUS_NONE
    for item in ["Нога: авто (по опоре)","Нога: ближняя (тест)","Нога: дальняя (тест)"]:leg.add_item(item)
    col.add_child(leg)
    leg.item_selected.connect(change_leg)
    trace_box=CheckBox.new()
    trace_box.text="Траектория и точка контакта"
    trace_box.button_pressed=true
    trace_box.focus_mode=Control.FOCUS_NONE
    col.add_child(trace_box)
    trace_box.toggled.connect(func(_on:bool):trace_changed.emit())
    previous_trace_box=CheckBox.new()
    previous_trace_box.text="Предыдущая · оранжевая линия"
    previous_trace_box.button_pressed=true
    previous_trace_box.focus_mode=Control.FOCUS_NONE
    col.add_child(previous_trace_box)
    previous_trace_box.toggled.connect(func(_on:bool):trace_changed.emit())
    var legend:Label=caption(col,"Бирюзовая — текущая · совмещение по опоре",13)
    legend.add_theme_color_override("font_color",Color("#73d9c5"))
    col.add_child(HSeparator.new())
    stats=caption(col,"",15)
    var row:=HBoxContainer.new()
    col.add_child(row)
    speed_choice=OptionButton.new()
    speed_choice.focus_mode=Control.FOCUS_NONE
    for value in SPEEDS:speed_choice.add_item("%.2f×"%value)
    row.add_child(speed_choice)
    speed_choice.item_selected.connect(func(i:int):speed_changed.emit(float(SPEEDS[i])))
    pause_button=button(row,"Пауза (P)")
    pause_button.pressed.connect(func():pause_requested.emit())
    var step_button:Button=button(row,"Кадр (N)")
    step_button.pressed.connect(func():step_requested.emit())
    launch=button(col,"Выполнить атаку")
    launch.pressed.connect(func():attack_requested.emit(index))
    var repeat_row:=HBoxContainer.new()
    col.add_child(repeat_row)
    repeat_button=button(repeat_row,"▶ Автоповтор")
    repeat_button.toggle_mode=true
    repeat_button.toggled.connect(func(on:bool):
        sync_repeat(on)
        repeat_changed.emit(on))
    caption(repeat_row,"Пауза, с",13)
    repeat_delay=SpinBox.new()
    repeat_delay.min_value=.2
    repeat_delay.max_value=3.
    repeat_delay.step=.1
    repeat_delay.value=.6
    repeat_delay.custom_minimum_size=Vector2(84,0)
    repeat_row.add_child(repeat_delay)
    repeat_delay.get_line_edit().editable=false
    repeat_delay.get_line_edit().focus_mode=Control.FOCUS_NONE
    var actions:=HBoxContainer.new()
    col.add_child(actions)
    var reset_button:Button=button(actions,"Сброс")
    reset_button.pressed.connect(reset_profile)
    var copy_button:Button=button(actions,"JSON →")
    copy_button.pressed.connect(copy_settings)
    var paste_button:Button=button(actions,"← JSON")
    paste_button.pressed.connect(paste_settings)
    feedback=caption(col,"",13)
    load_profile()

func caption(parent:Control,value:String,font_size:int)->Label:
    var l:=Label.new()
    l.text=value
    l.add_theme_font_size_override("font_size",font_size)
    parent.add_child(l)
    return l

func button(parent:Control,value:String)->Button:
    var b:=Button.new()
    b.text=value
    b.focus_mode=Control.FOCUS_NONE
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    parent.add_child(b)
    return b

func slider(parent:Control,id:String,title:String,low:float,high:float,inc:float)->void:
    var row:=HBoxContainer.new()
    parent.add_child(row)
    var l:Label=caption(row,title,16)
    l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    values[id]=caption(row,"",16)
    var control:=HSlider.new()
    control.min_value=low
    control.max_value=high
    control.step=inc
    control.focus_mode=Control.FOCUS_NONE
    control.custom_minimum_size=Vector2(0,20)
    parent.add_child(control)
    sliders[id]=control
    control.value_changed.connect(change_value.bind(id))

func select_attack(i:int)->void:
    index=i
    chooser.select(i)
    load_profile()
    trace_changed.emit()

func load_profile()->void:
    updating=true
    for id in sliders:
        sliders[id].set_value_no_signal(float(profiles[index][id]))
        update_readout(id)
    leg.select(int(profiles[index].leg)+1)
    updating=false
    update_timing()

func update_readout(id:String)->void:
    var v:float=float(profiles[index][id])
    values[id].text="%d"%roundi(v) if id.ends_with("_ticks") else "%d%%"%roundi(v*100.)

func update_timing()->void:
    var p:Dictionary=profiles[index]
    var total:int=int(p.prep_ticks+p.strike_ticks+p.return_ticks+p.recovery_ticks)
    timing.text="Всего: %d к. · %.3f с · акцент: %d к."%[total,total/60.,p.prep_ticks+p.strike_ticks]

func change_value(value:float,id:String)->void:
    if updating:return
    profiles[index][id]=roundi(value) if id.ends_with("_ticks") else value
    update_readout(id)
    update_timing()
    settings_changed.emit()

func change_leg(i:int)->void:
    if updating:return
    profiles[index].leg=i-1
    settings_changed.emit()

func reset_profile()->void:
    profiles[index]=Tuning.defaults(index==1)
    load_profile()
    settings_changed.emit()
    feedback.text="Сброшены параметры выбранной атаки"

func copy_settings()->void:
    DisplayServer.clipboard_set(JSON.stringify({"version":20,"K":profiles[0],"L":profiles[1]},"  "))
    feedback.text="JSON обеих атак скопирован"

func paste_settings()->void:
    var data=JSON.parse_string(DisplayServer.clipboard_get())
    if not data is Dictionary or not data.get("K") is Dictionary or not data.get("L") is Dictionary:
        feedback.text="Нужен JSON с объектами K и L"
        return
    profiles=[Tuning.normalize(data.K,false),Tuning.normalize(data.L,true)]
    load_profile()
    settings_changed.emit()
    feedback.text="JSON загружен для следующих атак"

func sync_repeat(on:bool)->void:
    repeat_button.set_pressed_no_signal(on)
    repeat_button.text="■ Стоп повтор" if on else "▶ Автоповтор"

func sync_speed(value:float)->void:
    for i in SPEEDS.size():
        if is_equal_approx(value,float(SPEEDS[i])):speed_choice.select(i)

func set_status(actor,paused:bool,can_launch:bool)->void:
    pause_button.text="Продолжить" if paused else "Пауза (P)"
    launch.disabled=not can_launch
    if actor.trace.is_empty():
        stats.text=("Прошлый замер сохранён. Выполни атаку." if not actor.previous_trace.is_empty() else "Нет измерений. Выполни выбранную атаку.")+"\nСкорость · ед. рига/с; дальность · ед. рига"
        return
    var state:String=actor.phase_name() if actor.active else "Последний замер"
    var surface:String="голень" if index==1 else "пятка"
    stats.text="%s · %d/%d · %s\nНога: %s · поверхность: %s\nV: %.1f · пик выброса: %.1f ед./с\nДальность: %.1f · макс.: %.1f ед.\nНа акценте: %s"%[state,actor.age,actor.end_tick,"запись" if actor.active else "готово","ближняя" if actor.striking==0 else "дальняя",surface,actor.current_speed,actor.peak_speed,actor.current_reach,actor.peak_reach,"%.1f ед."%actor.impact_reach if actor.trace_hit_index>=0 else "—"]
