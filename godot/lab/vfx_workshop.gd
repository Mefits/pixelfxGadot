extends Control
const UI=preload("res://lab/ui_ru.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const STAGE=preload("res://lab/vfx_stage.gd")
const TIMELINE=preload("res://lab/vfx_timeline.gd")
var preset: Dictionary=P.demo()
var renderer=R.new()
var stage
var surface
var timeline
var list: ItemList
var fields: Dictionary={}
var name_edit: LineEdit
var library: OptionButton
var kind: OptionButton
var status: Label
var perf: Label
var play_button: Button
var seek: HSlider
var selected: int=0
var time: float=.3
var playing: bool=true
var loop: bool=true
var dirty: bool=true
var syncing: bool=false
var clock: float=0

func _label(parent: Control,value: String) -> Label:
    var l:=Label.new()
    l.text=value
    parent.add_child(l)
    return l
func _button(parent: Control,value: String,cb: Callable) -> Button:
    var b:=Button.new()
    b.text=value
    parent.add_child(b)
    b.pressed.connect(cb)
    return b
func _option(parent: Control,values: Array,cb: Callable) -> OptionButton:
    var o:=OptionButton.new()
    for v in values:o.add_item(UI.label(str(v)))
    parent.add_child(o)
    o.item_selected.connect(cb)
    return o
func _ready() -> void:
    var theme0:=Theme.new()
    theme0.default_font_size=13
    theme=theme0
    var bg:=ColorRect.new()
    bg.color=Color("#101722")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var title:=Label.new()
    title.text="КОНСТРУКТОР ЭФФЕКТОВ / PixelFX"
    title.position=Vector2(12,8)
    title.add_theme_font_size_override("font_size",22)
    add_child(title)
    var left:=VBoxContainer.new()
    left.position=Vector2(12,44)
    left.size=Vector2(172,475)
    add_child(left)
    _label(left,"ПРЕСЕТЫ")
    var demos=_option(left,["Электроразряд","Кислота","Удар когтем","Вспышка огня"],func(i:int):preset=P.demo(i);selected=0;_refresh())
    name_edit=LineEdit.new()
    name_edit.placeholder_text="Имя эффекта"
    left.add_child(name_edit)
    name_edit.text_changed.connect(func(v:String):preset.name=v)
    var io:=HBoxContainer.new()
    left.add_child(io)
    _button(io,"Сохранить",_save)
    _button(io,"Загрузить",_load)
    library=OptionButton.new()
    left.add_child(library)
    _label(left,"СЛОИ (порядок)")
    list=ItemList.new()
    list.custom_minimum_size=Vector2(166,185)
    left.add_child(list)
    list.item_selected.connect(func(i:int):selected=i;_sync_fields())
    kind=_option(left,P.TYPES,func(_i:int):pass)
    var addrow:=HBoxContainer.new()
    left.add_child(addrow)
    _button(addrow,"+ Слой",_add_layer)
    _button(addrow,"Копия",_copy_layer)
    _button(addrow,"−",_delete_layer)
    var order:=HBoxContainer.new()
    left.add_child(order)
    _button(order,"↑",func():_move_layer(-1))
    _button(order,"↓",func():_move_layer(1))
    _button(order,"Меню",func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    status=_label(left,"")
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(240,160)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    stage=STAGE.new()
    viewport.add_child(stage)
    surface=SURFACE.new()
    viewport.add_child(surface)
    surface.configure(240,160)
    var picture:=TextureRect.new()
    picture.position=Vector2(194,44)
    picture.size=Vector2(480,320)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    picture.texture=viewport.get_texture()
    add_child(picture)
    var controls:=HBoxContainer.new()
    controls.position=Vector2(194,370)
    add_child(controls)
    play_button=_button(controls,"Пауза",_toggle_play)
    _button(controls,"Сначала",func():time=0;playing=true;dirty=true)
    _button(controls,"Цикл",func():loop=not loop;status.text="Цикл: "+str(loop))
    _button(controls,"Движение",func():stage.moving=not stage.moving;dirty=true)
    _button(controls,"Фон",func():stage.bright=not stage.bright;dirty=true)
    _button(controls,"Seed",func():preset.seed=int(preset.seed)+1;dirty=true)
    _button(controls,"C++",func():renderer.enable_acceleration(not renderer.accelerated);dirty=true)
    perf=Label.new()
    perf.position=Vector2(194,401)
    add_child(perf)
    seek=HSlider.new()
    seek.position=Vector2(194,426)
    seek.size=Vector2(480,20)
    seek.step=.001
    add_child(seek)
    seek.value_changed.connect(func(v:float):
        if not syncing:_seek(v))
    timeline=TIMELINE.new()
    timeline.position=Vector2(194,450)
    timeline.size=Vector2(480,81)
    add_child(timeline)
    timeline.seek_requested.connect(_seek)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(686,44)
    scroll.size=Vector2(262,483)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var right:=VBoxContainer.new()
    right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(right)
    _label(right,"ПАРАМЕТРЫ СЛОЯ")
    for spec in [["type","Тип",P.TYPES],["anchor","Привязка",P.ANCHORS],["curve","Кривая",P.CURVES]]:
        var row:=HBoxContainer.new()
        right.add_child(row)
        var label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var key: String=spec[0]
        var options: Array=spec[2]
        fields[key]=_option(row,options,func(i:int):_change(key,options[i]))
    for spec in [["enabled","Видимость"],["follow","Следовать за точкой"],["collision","Столкновение с полом"]]:
        var check:=CheckButton.new()
        check.text=spec[1]
        right.add_child(check)
        fields[spec[0]]=check
        var key: String=spec[0]
        check.toggled.connect(func(v:bool):_change(key,v))
    var color:=ColorPickerButton.new()
    color.custom_minimum_size.y=30
    color.edit_alpha=false
    right.add_child(color)
    fields.color=color
    color.color_changed.connect(func(c:Color):_change("color","#"+c.to_html(false)))
    for spec in [["start","Начало, с",0,5,.01],["duration","Время жизни, с",.05,5,.01],["size","Размер: начало",.5,80,.5],["end_size","Размер: конец",.5,80,.5],["alpha","Непрозр.: начало",0,1,.05],["end_alpha","Непрозр.: конец",0,1,.05],["speed","Скорость: начало",0,200,1],["end_speed","Скорость: конец",0,200,1],["count","Количество",1,64,1],["spread","Разброс, °",0,360,1],["angle","Угол, °",-180,180,1],["gravity","Гравитация",-200,300,5],["glow","Свечение",0,1,.05],["x","Смещение X",-100,100,1],["y","Смещение Y",-100,100,1]]:
        var row:=HBoxContainer.new()
        right.add_child(row)
        var label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=88
        row.add_child(spin)
        var key: String=spec[0]
        fields[key]=spin
        spin.value_changed.connect(func(v:float):_change(key,v))
    renderer.enable_acceleration()
    _library()
    _refresh()
func _toggle_play() -> void:
    playing=not playing
    if playing and time>=P.duration(preset):time=0
func _seek(v: float) -> void:
    time=clampf(v,0,P.duration(preset))
    playing=false
    dirty=true
func _change(key: String,v: Variant) -> void:
    if syncing:return
    preset.layers[selected][key]=v
    if key in ["type","enabled"]:_refresh()
    else:dirty=true
func _refresh() -> void:
    list.clear()
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        list.add_item("%d  %s %s"%[i+1,UI.label(l.type),"" if l.enabled else "(выкл.)"])
    selected=clampi(selected,0,preset.layers.size()-1)
    list.select(selected)
    name_edit.text=UI.label(preset.name)
    _sync_fields()
func _sync_fields() -> void:
    syncing=true
    var l: Dictionary=preset.layers[selected]
    for key in fields:
        var field=fields[key]
        if field is OptionButton:
            var options: Array=P.TYPES if key=="type" else (P.ANCHORS if key=="anchor" else P.CURVES)
            field.select(options.find(l[key]))
        elif field is CheckButton:field.button_pressed=l[key]
        elif field is ColorPickerButton:field.color=Color(l[key])
        else:field.value=float(l[key])
    syncing=false
    dirty=true
func _add_layer() -> void:
    if preset.layers.size()>=P.MAX_LAYERS:return
    preset.layers.append(P.layer(P.TYPES[kind.selected]))
    selected=preset.layers.size()-1
    _refresh()
func _copy_layer() -> void:
    if preset.layers.size()>=P.MAX_LAYERS:return
    preset.layers.insert(selected+1,preset.layers[selected].duplicate(true))
    selected+=1
    _refresh()
func _delete_layer() -> void:
    if preset.layers.size()<=1:return
    preset.layers.remove_at(selected)
    _refresh()
func _move_layer(delta: int) -> void:
    var other: int=selected+delta
    if other<0 or other>=preset.layers.size():return
    var l: Dictionary=preset.layers[selected]
    preset.layers[selected]=preset.layers[other]
    preset.layers[other]=l
    selected=other
    _refresh()
func _library() -> void:
    library.clear()
    DirAccess.make_dir_recursive_absolute(P.FOLDER)
    var dir:=DirAccess.open(P.FOLDER)
    if dir==null:return
    for f in dir.get_files():
        if f.ends_with(".json"):library.add_item(f)
func _save() -> void:
    status.text="Сохранено в user://vfx_presets" if P.save_preset(preset) else "Неверный пресет"
    _library()
func _load() -> void:
    if library.selected<0:return
    var value: Dictionary=P.load_preset(P.FOLDER.path_join(library.get_item_text(library.selected)))
    if value.is_empty():status.text="Неверный файл";return
    preset=value
    selected=0
    _refresh()
func _process(dt: float) -> void:
    if surface==null:return
    clock+=dt
    if playing and clock>=1.0/30:
        time+=clock
        var end: float=P.duration(preset)
        if time>=end:
            if loop:time=fposmod(time,end)
            else:time=end;playing=false
        dirty=true
    if dirty:
        clock=0
        time=minf(time,P.duration(preset))
        stage.time=time
        stage.queue_redraw()
        renderer.render(surface.painter,preset,time,{},128,stage.anchor)
        surface.present()
        timeline.preset=preset
        timeline.time=time
        timeline.selected=selected
        timeline.queue_redraw()
        syncing=true
        seek.max_value=P.duration(preset)
        seek.value=time
        syncing=false
        perf.text="%.2f с | слоёв %d | частиц %d | %.2f мс | %s"%[time,renderer.active_layers,renderer.particles,renderer.render_ms,"C++" if renderer.accelerated else "GDScript"]
        dirty=false
    play_button.text="Пауза" if playing else "Пуск"
func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo and UI.physical_key(e)==KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
