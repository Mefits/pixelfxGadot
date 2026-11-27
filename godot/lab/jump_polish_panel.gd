extends PanelContainer
## Presentation only: the training controller remains the source of truth.
const Jump=preload("res://lab/jump_control.gd")
signal jump_requested(direction:int)
signal pause_requested
signal step_requested
signal speed_changed(value:float)
signal trace_changed

var sliders:Dictionary={}
var readouts:Dictionary={}
var progress_label:Label
var pause_button:Button
var step_button:Button
var launch_buttons:Array[Button]=[]
var launch_caption:Label
var trace_box:CheckBox
var speed_choice:OptionButton
var copy_button:Button
const SPEEDS=[1.,.5,.25,.1]

func _ready()->void:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("#18232eF5")
    style.set_corner_radius_all(8)
    style.content_margin_left=14.
    style.content_margin_right=14.
    style.content_margin_top=12.
    style.content_margin_bottom=12.
    add_theme_stylebox_override("panel",style)
    custom_minimum_size=Vector2(350,0)
    var content:=VBoxContainer.new()
    content.add_theme_constant_override("separation",7)
    add_child(content)
    add_caption(content,"ПОЛИРОВКА ПРЫЖКА",23)
    add_caption(content,"Настройки фиксируются до приземления",14)
    add_slider(content,"height_scale","Высота · рост бойца",.5,1.7,.05,Jump.DEFAULTS.height_scale)
    add_slider(content,"flight_seconds","Время полёта · с",.4,1.4,.05,Jump.DEFAULTS.flight_seconds)
    add_slider(content,"power_scale","Выразительность толчка",.5,1.5,.05,Jump.DEFAULTS.power_scale)
    add_slider(content,"tuck_scale","Группировка в воздухе",0.,1.5,.05,Jump.DEFAULTS.tuck_scale)
    content.add_child(HSeparator.new())
    add_caption(content,"Второй импульс",17)
    add_slider(content,"second_height_scale","Доп. высота · рост",.25,.8,.05,Jump.DEFAULTS.second_height_scale)
    add_slider(content,"second_speed_scale","Горизонтальная скорость",1.,1.5,.05,Jump.DEFAULTS.second_speed_scale)
    add_slider(content,"second_power_scale","Пластика толчка",.5,1.5,.05,Jump.DEFAULTS.second_power_scale)
    content.add_child(HSeparator.new())
    launch_caption=add_caption(content,"Прыжок из текущей стойки",17)
    var launches:=HBoxContainer.new()
    content.add_child(launches)
    for direction in [-1,0,1]:
        var b:Button=make_button(launches,["Назад","Вверх","Вперёд"][direction+1])
        b.pressed.connect(request_jump.bind(direction))
        launch_buttons.append(b)
    add_caption(content,"Скорость просмотра",17)
    speed_choice=OptionButton.new()
    speed_choice.focus_mode=Control.FOCUS_NONE
    speed_choice.add_theme_font_size_override("font_size",18)
    for caption in ["1× — обычная","0,5×","0,25×","0,1×"]:speed_choice.add_item(caption)
    speed_choice.select(0)
    speed_choice.item_selected.connect(change_speed)
    content.add_child(speed_choice)
    var playback:=HBoxContainer.new()
    content.add_child(playback)
    pause_button=make_button(playback,"Пауза (P)")
    pause_button.pressed.connect(func():pause_requested.emit())
    step_button=make_button(playback,"Кадр +1 (N)")
    step_button.pressed.connect(func():step_requested.emit())
    trace_box=CheckBox.new()
    trace_box.text="Показывать траекторию"
    trace_box.button_pressed=true
    trace_box.focus_mode=Control.FOCUS_NONE
    trace_box.add_theme_font_size_override("font_size",17)
    trace_box.toggled.connect(func(_enabled:bool):trace_changed.emit())
    content.add_child(trace_box)
    progress_label=add_caption(content,"Готов к прыжку",16)
    var actions:=HBoxContainer.new()
    content.add_child(actions)
    var defaults:Button=make_button(actions,"Сбросить")
    defaults.pressed.connect(reset_settings)
    copy_button=make_button(actions,"Копировать JSON")
    copy_button.pressed.connect(copy_settings)

func add_caption(parent:Control,value:String,font_size:int)->Label:
    var l:=Label.new()
    l.text=value
    l.add_theme_font_size_override("font_size",font_size)
    parent.add_child(l)
    return l

func make_button(parent:Control,value:String)->Button:
    var b:=Button.new()
    b.text=value
    b.focus_mode=Control.FOCUS_NONE
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size",16)
    parent.add_child(b)
    return b

func add_slider(parent:Control,id:String,caption:String,low:float,high:float,increment:float,initial:float)->void:
    var row:=HBoxContainer.new()
    parent.add_child(row)
    var title:Label=add_caption(row,caption,17)
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    readouts[id]=add_caption(row,"",17)
    var slider:=HSlider.new()
    slider.min_value=low
    slider.max_value=high
    slider.step=increment
    slider.value=initial
    slider.focus_mode=Control.FOCUS_NONE
    slider.custom_minimum_size=Vector2(0,24)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    parent.add_child(slider)
    sliders[id]=slider
    slider.value_changed.connect(update_value.bind(id))
    update_value(initial,id)

func update_value(value:float,id:String)->void:
    readouts[id].text=("%d%%"%roundi(value*100.) if id in ["power_scale","tuck_scale","second_speed_scale","second_power_scale"] else "%.2f"%value)
    if copy_button!=null:copy_button.text="Копировать JSON"

func settings()->Dictionary:
    var result:Dictionary={}
    for id in sliders:result[id]=float(sliders[id].value)
    return result

func reset_settings()->void:
    var defaults:Dictionary=Jump.DEFAULTS
    for id in defaults:sliders[id].value=defaults[id]

func copy_settings()->void:
    DisplayServer.clipboard_set(JSON.stringify(settings(),"  "))
    copy_button.text="Скопировано"

func request_jump(direction:int)->void:
    jump_requested.emit(direction)

func change_speed(index:int)->void:
    speed_changed.emit(float(SPEEDS[index]))

func set_status(paused:bool,can_launch:bool,description:String,can_second:bool=false)->void:
    pause_button.text="Продолжить (P)" if paused else "Пауза (P)"
    launch_caption.text="Воздушный толчок" if can_second else "Прыжок из текущей стойки"
    for b in launch_buttons:b.disabled=not (can_launch or can_second)
    progress_label.text=description
