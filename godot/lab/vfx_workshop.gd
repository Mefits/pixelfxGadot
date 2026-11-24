extends Control
const CAT=preload("res://addons/creature/catalog.gd")
var catalog_entry:Dictionary={}
const UI=preload("res://lab/ui_ru.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const STAGE=preload("res://lab/vfx_stage.gd")
const TIMELINE=preload("res://lab/vfx_timeline.gd")
const GRAPH=preload("res://lab/vfx_curve_editor.gd")
const QUICK=preload("res://lab/vfx_quick_dialog.gd")
var quick_dialog
const BINDINGS=preload("res://addons/creature/vfx_bindings.gd")
var binding_bank: Dictionary={}
var binding_role: OptionButton
var binding_info: Label
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
var graph
var curve_channel: int=0
var curve_toggle: Button
var curve_status: Label
var emitter_panel: VBoxContainer
var emitter_controls: VBoxContainer
var emitter_toggle: CheckButton
var emitter_fields: Dictionary={}
var emitter_info: Label
var trail_panel: VBoxContainer
var trail_fields: Dictionary={}
var organic_panel: VBoxContainer
var organic_fields: Dictionary={}
var organic_hint: Label
var field_panel: VBoxContainer
var field_parameters: Dictionary={}
var field_hint: Label
var inspector: TabContainer
var field_rows: Dictionary={}
var curve_selector: OptionButton
var picture: TextureRect
var compare_picture: TextureRect
var compare_surface
var compare_stage
var compare_viewport: SubViewport
var compare_renderer
var reference: Dictionary={}
var compare_button: Button
var compare_labels: HBoxContainer
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
    var demos=_option(left,["Электроразряд","Кислота","Удар когтем","Вспышка огня","Поток энергии","Электрический шлейф","Живая ткань","Ударная волна","Энергетический луч","Вихрь","Энергетическая сфера","Разлом"],_select_demo)
    demos.fit_to_longest_item=false
    demos.clip_text=true
    preset.name=UI.label(preset.name)
    name_edit=LineEdit.new()
    name_edit.placeholder_text="Имя эффекта"
    left.add_child(name_edit)
    name_edit.text_changed.connect(func(v:String):preset.name=v)
    var io:=HBoxContainer.new()
    left.add_child(io)
    _button(io,"Сохранить",_save)
    _button(io,"Загрузить",_load)
    library=OptionButton.new()
    library.fit_to_longest_item=false
    library.clip_text=true
    left.add_child(library)
    _label(left,"СЛОИ (порядок)")
    list=ItemList.new()
    list.custom_minimum_size=Vector2(166,185)
    left.add_child(list)
    list.item_selected.connect(func(i:int):selected=i;_sync_fields())
    kind=_option(left,P.TYPES,func(_i:int):pass)
    kind.fit_to_longest_item=false
    kind.clip_text=true
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
    picture=TextureRect.new()
    picture.position=Vector2(194,44)
    picture.size=Vector2(480,320)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    picture.texture=viewport.get_texture()
    add_child(picture)
    var controls:=HBoxContainer.new()
    controls.position=Vector2(194,366)
    add_child(controls)
    play_button=_button(controls,"Пауза",_toggle_play)
    _button(controls,"Сначала",func():time=0;playing=true;dirty=true)
    _button(controls,"Цикл",func():loop=not loop;status.text="Цикл: "+str(loop))
    _button(controls,"Движение",func():stage.moving=not stage.moving;dirty=true)
    _button(controls,"Фон",func():stage.bright=not stage.bright;dirty=true)
    var variant:=_button(controls,"Вариант",func():preset.seed=int(preset.seed)+1;dirty=true)
    variant.tooltip_text="Новая случайная конфигурация при тех же параметрах"
    _button(controls,"C++",func():renderer.enable_acceleration(not renderer.accelerated);dirty=true)
    var compare_row:=HBoxContainer.new()
    compare_row.position=Vector2(194,394)
    add_child(compare_row)
    _button(compare_row,"Запомнить A",_capture_reference)
    compare_button=_button(compare_row,"A / B",_toggle_compare)
    compare_button.disabled=true
    _button(compare_row,"Сброс масштаба",func():timeline.reset_view())
    _button(compare_row,"Быстрая настройка",_quick_open)
    quick_dialog=QUICK.new()
    add_child(quick_dialog)
    quick_dialog.applied.connect(_quick_apply)
    perf=Label.new()
    perf.position=Vector2(194,420)
    perf.add_theme_font_size_override("font_size",10)
    add_child(perf)
    seek=HSlider.new()
    seek.position=Vector2(194,435)
    seek.size=Vector2(480,20)
    seek.step=.001
    add_child(seek)
    seek.value_changed.connect(func(v:float):
        if not syncing:_seek(v))
    timeline=TIMELINE.new()
    timeline.position=Vector2(194,457)
    timeline.size=Vector2(480,74)
    add_child(timeline)
    timeline.seek_requested.connect(_seek)
    timeline.layer_requested.connect(_select_layer)
    inspector=TabContainer.new()
    inspector.position=Vector2(686,44)
    inspector.size=Vector2(262,483)
    add_child(inspector)
    var right: VBoxContainer=_inspector_page("Слой")
    var shape_page: VBoxContainer=_inspector_page("Форма")
    var curve_page: VBoxContainer=_inspector_page("Кривые")
    var combat_page: VBoxContainer=_inspector_page("Бой")
    _label(combat_page,"ЭФФЕКТ ДЛЯ СОБЫТИЯ")
    binding_bank=BINDINGS.load_bank()
    binding_role=_option(combat_page,["Заряд","Магия","Удар","Удар другой рукой","Тяжёлый удар","Удар ногой","Удар в воздухе","Попадание","Блок"],func(_i:int):_binding_sync())
    binding_role.fit_to_longest_item=false
    binding_role.clip_text=true
    _button(combat_page,"Назначить текущий",_bind_current)
    _button(combat_page,"Вернуть стандартный",_unbind_current)
    _button(combat_page,"Открыть привязанный",_load_bound)
    _button(combat_page,"В боевую лабораторию",func():get_tree().change_scene_to_file("res://lab/combat_lab.tscn"))
    binding_info=_label(combat_page,"")
    binding_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var binding_hint: Label=_label(combat_page,"Назначение хранит копию эффекта. Редактируй и назначай заново. В бою «Рука» означает конечность из маркера анимации, в том числе ногу; «Цель» — точка события.")
    binding_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _binding_sync()
    _label(right,"ПАРАМЕТРЫ СЛОЯ")
    for spec in [["type","Тип",P.TYPES],["anchor","Привязка",P.ANCHORS],["curve","Кривая",P.CURVES]]:
        var row:=HBoxContainer.new()
        right.add_child(row)
        var label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var key: String=spec[0]
        var options: Array=spec[2]
        fields[key]=_option(row,options,func(i:int):_change(key,options[i]))
        fields[key].size_flags_horizontal=Control.SIZE_EXPAND_FILL
        fields[key].fit_to_longest_item=false
        fields[key].clip_text=true
        field_rows[key]=row
    emitter_panel=VBoxContainer.new()
    shape_page.add_child(emitter_panel)
    _label(emitter_panel,"ИСТОЧНИК ЧАСТИЦ")
    emitter_toggle=CheckButton.new()
    emitter_toggle.text="Непрерывный поток"
    emitter_panel.add_child(emitter_toggle)
    emitter_toggle.toggled.connect(_toggle_emitter)
    emitter_controls=VBoxContainer.new()
    emitter_panel.add_child(emitter_controls)
    for spec in [["rate","Частиц / с",1,64,1],["life","Жизнь частицы, с",.05,3,.01],["life_jitter","Разброс жизни",0,.8,.05],["radius","Радиус источника",0,40,1]]:
        var row:=HBoxContainer.new()
        emitter_controls.add_child(row)
        var label: Label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=88
        row.add_child(spin)
        var key: String=spec[0]
        emitter_fields[key]=spin
        spin.value_changed.connect(func(v:float):_emitter_change(key,v))
    var shape_row:=HBoxContainer.new()
    emitter_controls.add_child(shape_row)
    var shape_label: Label=_label(shape_row,"Форма")
    shape_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    emitter_fields.shape=_option(shape_row,["Точка","Диск","Кольцо","Линия"],func(i:int):_emitter_change("shape",P.EMITTER_SHAPES[i]))
    emitter_info=_label(emitter_controls,"")
    emitter_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    trail_panel=VBoxContainer.new()
    shape_page.add_child(trail_panel)
    _label(trail_panel,"ДИНАМИЧЕСКИЙ ШЛЕЙФ")
    for spec in [["life","Жизнь следа, с",.05,1.5,.01],["rate","Проб / с",8,64,1],["break_distance","Разрыв, px",4,120,1],["jitter","Зигзаг, px",0,12,.5]]:
        var row:=HBoxContainer.new()
        trail_panel.add_child(row)
        var label: Label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=88
        row.add_child(spin)
        var key: String=spec[0]
        trail_fields[key]=spin
        spin.value_changed.connect(func(v:float):_trail_change(key,v))
    var trail_style_row:=HBoxContainer.new()
    trail_panel.add_child(trail_style_row)
    var trail_style_label: Label=_label(trail_style_row,"Стиль")
    trail_style_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    trail_fields.style=_option(trail_style_row,["Лента","Электрический","Точки"],func(i:int):_trail_change("style",P.TRAIL_STYLES[i]))
    var trail_hint: Label=_label(trail_panel,"Включи «Движение»: след строится по истории точки. Размер = ширина.")
    trail_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    organic_panel=VBoxContainer.new()
    shape_page.add_child(organic_panel)
    _label(organic_panel,"ОРГАНИЧЕСКАЯ ДЕФОРМАЦИЯ")
    for spec in [["arms","Отростков",1,8,1],["length","Длина, px",4,96,1],["wave","Амплитуда, px",0,32,.5],["frequency","Частота, Гц",0,6,.1],["taper","Сужение",0,1,.05],["pulse","Пульсация",0,.45,.05],["stretch","Растяжение",0,.65,.05]]:
        var row:=HBoxContainer.new()
        organic_panel.add_child(row)
        var label: Label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=88
        row.add_child(spin)
        var key: String=spec[0]
        organic_fields[key]=spin
        spin.value_changed.connect(func(v:float):_organic_change(key,v))
    var aim:=CheckButton.new()
    aim.text="Направить к цели"
    organic_panel.add_child(aim)
    organic_fields.aim=aim
    aim.toggled.connect(func(v:bool):_organic_change("aim",v))
    organic_hint=_label(organic_panel,"")
    organic_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    field_panel=VBoxContainer.new()
    shape_page.add_child(field_panel)
    _label(field_panel,"ФОРМА ЭФФЕКТА")
    for spec in [["thickness","Толщина, px",.5,12,.5],["length","Длина, px",4,160,1],["aspect","Пропорции",.15,1,.05],["rotation","Вращение, °/с",-720,720,10],["distortion","Искажение",0,1,.05]]:
        var row:=HBoxContainer.new()
        field_panel.add_child(row)
        var label: Label=_label(row,spec[1])
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=88
        row.add_child(spin)
        var key: String=spec[0]
        field_parameters[key]=spin
        spin.value_changed.connect(func(v:float):_field_change(key,v))
    var field_aim:=CheckButton.new()
    field_aim.text="Направить к цели"
    field_panel.add_child(field_aim)
    field_parameters.aim=field_aim
    field_aim.toggled.connect(func(v:bool):_field_change("aim",v))
    field_hint=_label(field_panel,"")
    field_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _label(curve_page,"КРИВЫЕ ПАРАМЕТРОВ")
    curve_selector=_option(curve_page,["Размер","Прозрачность","Скорость","Свечение"],func(i:int):curve_channel=i;_sync_curve())
    curve_toggle=_button(curve_page,"Своя кривая",_toggle_curve)
    graph=GRAPH.new()
    curve_page.add_child(graph)
    graph.points_changed.connect(_curve_changed)
    curve_status=_label(curve_page,"")
    curve_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var hint: Label=_label(curve_page,"ЛКМ: добавить / двигать. ПКМ: удалить внутреннюю точку.")
    hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for spec in [["enabled","Видимость"],["follow","Следовать за точкой"],["collision","Столкновение с полом"]]:
        var check:=CheckButton.new()
        check.text=spec[1]
        right.add_child(check)
        fields[spec[0]]=check
        field_rows[spec[0]]=check
        var key: String=spec[0]
        check.toggled.connect(func(v:bool):_change(key,v))
    var color:=ColorPickerButton.new()
    color.custom_minimum_size.y=30
    color.edit_alpha=false
    right.add_child(color)
    fields.color=color
    field_rows.color=color
    color.color_changed.connect(func(c:Color):_change("color","#"+c.to_html(false)))
    for spec in [["start","Начало, с",0,5,.01],["duration","Время жизни, с",.05,5,.01],["size","Размер: начало",.5,80,.5],["end_size","Размер: конец",.5,80,.5],["alpha","Непрозр.: начало",0,1,.05],["end_alpha","Непрозр.: конец",0,1,.05],["speed","Скорость: начало",0,200,1],["end_speed","Скорость: конец",0,200,1],["count","Количество",1,64,1],["spread","Разброс, °",0,360,1],["angle","Угол, °",-180,180,1],["gravity","Гравитация",-200,300,5],["glow","Свечение",0,1,.05],["x","Смещение X",-100,100,1],["y","Смещение Y",-100,100,1]]:
        var row:=HBoxContainer.new()
        var destination: VBoxContainer=shape_page if spec[0] in ["count","spread","angle","gravity","speed","end_speed"] else right
        destination.add_child(row)
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
        field_rows[key]=row
        spin.value_changed.connect(func(v:float):_change(key,v))
    # The comparison viewport is allocated only when requested.
    compare_labels=HBoxContainer.new()
    compare_labels.position=Vector2(194,58)
    compare_labels.size=Vector2(480,24)
    add_child(compare_labels)
    for label_text in ["B — текущий","A — образец"]:
        var label: Label=_label(compare_labels,label_text)
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    compare_labels.hide()
    renderer.enable_acceleration()
    _library()
    catalog_entry=CAT.consume(get_tree(),"vfx")
    if not catalog_entry.is_empty():
        preset=catalog_entry.payload.duplicate(true)
        selected=0
        time=0
        stage.sweep=false
        for l in preset.layers:
            if l.type=="trail":stage.moving=true;stage.sweep=true;break
        status.text="Библиотека: сохранение в отдельную копию."
    _refresh()
func _quick_open() -> void:
    playing=false
    quick_dialog.open_for(preset)

func _quick_apply(value: Dictionary) -> void:
    if not P.valid(value):return
    # Preserve the old effect for A/B comparison before applying.
    _capture_reference()
    preset=value
    _refresh()
    status.text="Настроено. Исходник сохранён как A."

func _binding_sync() -> void:
    if binding_info==null:return
    var role: String=BINDINGS.ROLES[maxi(0,binding_role.selected)]
    binding_info.text="Назначен: "+str(binding_bank[role].name) if binding_bank.has(role) else "Стандартный эффект."

func _bind_current() -> void:
    var role: String=BINDINGS.ROLES[maxi(0,binding_role.selected)]
    var next: Dictionary=binding_bank.duplicate(true)
    next[role]=preset.duplicate(true)
    if BINDINGS.save_bank(next):
        binding_bank=next
        _binding_sync()
    else:binding_info.text="Не удалось сохранить назначение."

func _unbind_current() -> void:
    var role: String=BINDINGS.ROLES[maxi(0,binding_role.selected)]
    var next: Dictionary=binding_bank.duplicate(true)
    next.erase(role)
    if BINDINGS.save_bank(next):
        binding_bank=next
        _binding_sync()
    else:binding_info.text="Не удалось сохранить назначение."

func _load_bound() -> void:
    var role: String=BINDINGS.ROLES[maxi(0,binding_role.selected)]
    if not binding_bank.has(role):return
    preset=binding_bank[role].duplicate(true)
    selected=0
    stage.sweep=false
    for l in preset.layers:
        if l.type=="trail":stage.moving=true;stage.sweep=true;break
    _refresh()

func _inspector_page(label_text: String) -> VBoxContainer:
    var scroll:=ScrollContainer.new()
    scroll.name=label_text
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    inspector.add_child(scroll)
    var content:=VBoxContainer.new()
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    return content

func _select_layer(index: int) -> void:
    if index<0 or index>=preset.layers.size():return
    selected=index
    list.select(index)
    _sync_fields()

func _capture_reference() -> void:
    reference=preset.duplicate(true)
    compare_button.disabled=false
    status.text="Образец A запомнен."
    dirty=true

func _make_compare() -> void:
    if compare_viewport!=null:return
    compare_viewport=SubViewport.new()
    compare_viewport.size=Vector2i(240,160)
    add_child(compare_viewport)
    compare_stage=STAGE.new()
    compare_viewport.add_child(compare_stage)
    compare_surface=SURFACE.new()
    compare_viewport.add_child(compare_surface)
    compare_surface.configure(240,160)
    compare_renderer=R.new()
    compare_picture=TextureRect.new()
    compare_picture.position=Vector2(434,112)
    compare_picture.size=Vector2(240,160)
    compare_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    compare_picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    compare_picture.texture=compare_viewport.get_texture()
    add_child(compare_picture)

func _toggle_compare() -> void:
    if reference.is_empty():return
    _make_compare()
    var show_compare: bool=not compare_labels.visible
    compare_labels.visible=show_compare
    compare_picture.visible=show_compare
    compare_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if show_compare else SubViewport.UPDATE_DISABLED
    picture.position=Vector2(194,112) if show_compare else Vector2(194,44)
    picture.size=Vector2(240,160) if show_compare else Vector2(480,320)
    compare_button.text="Один вид" if show_compare else "A / B"
    dirty=true

func _effect_duration() -> float:
    return maxf(P.duration(preset),P.duration(reference)) if compare_labels!=null and compare_labels.visible else P.duration(preset)

func _select_demo(i: int) -> void:
    preset=P.demo(i)
    preset.name=UI.label(preset.name)
    selected=0
    if i==5:
        stage.moving=true
        stage.sweep=true
        time=.5
    else:
        stage.sweep=false
        if i==6:time=.7
        if i>=7:time=float(preset.layers[0].duration)*.4
    _refresh()

func _toggle_play() -> void:
    playing=not playing
    if playing and time>=_effect_duration():time=0
func _seek(v: float) -> void:
    time=clampf(v,0,_effect_duration())
    playing=false
    dirty=true
func _change(key: String,v: Variant) -> void:
    if syncing:return
    preset.layers[selected][key]=v
    if key=="type":
        var l: Dictionary=preset.layers[selected]
        if not v in P.PARTICLE_TYPES:l.erase("emitter")
        if v=="trail":
            l.trail=P.trail_defaults()
            l.follow=false
        else:l.erase("trail")
        if v in P.ORGANIC_TYPES:
            if not l.has("organic"):l.organic=P.organic_defaults()
        else:l.erase("organic")
        if v in P.FIELD_TYPES:
            if not l.has("field"):l.field=P.field_defaults()
        else:l.erase("field")
    if key in ["type","enabled"]:_refresh()
    else:
        _sync_emitter()
        _sync_trail()
        _sync_organic()
        _sync_field()
        _sync_visibility()
        _sync_curve()
        dirty=true
func _refresh() -> void:
    list.clear()
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        list.add_item("%d  %s %s"%[i+1,UI.label(l.type),"" if l.enabled else "(выкл.)"])
    selected=clampi(selected,0,preset.layers.size()-1)
    list.select(selected)
    name_edit.text=preset.name
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
    _sync_emitter()
    _sync_trail()
    _sync_organic()
    _sync_field()
    _sync_visibility()
    _sync_curve()
    dirty=true

func _sync_trail() -> void:
    if trail_panel==null:return
    var l: Dictionary=preset.layers[selected]
    var active: bool=l.type=="trail"
    trail_panel.visible=active
    for key in ["follow","collision"]:
        if fields.has(key):
            fields[key].disabled=active
            fields[key].tooltip_text="Шлейф использует историю мировых координат" if active else ""
    for key in ["count","spread","angle","gravity"]:
        if fields.has(key):
            fields[key].editable=not active and (key!="count" or not P.is_stream(l))
    if not active:return
    var previous: bool=syncing
    syncing=true
    for key in trail_fields:
        if key=="style":trail_fields[key].select(P.TRAIL_STYLES.find(l.trail.style))
        else:trail_fields[key].set_value_no_signal(float(l.trail[key]))
    trail_fields.jitter.editable=l.trail.style=="electric"
    syncing=previous

func _trail_change(key: String,value: Variant) -> void:
    if syncing:return
    var l: Dictionary=preset.layers[selected]
    if l.type!="trail":return
    l.trail[key]=value
    _sync_trail()
    _sync_visibility()
    dirty=true

func _sync_organic() -> void:
    if organic_panel==null:return
    var l: Dictionary=preset.layers[selected]
    var active: bool=l.type in P.ORGANIC_TYPES
    organic_panel.visible=active
    if not active:return
    var previous: bool=syncing
    syncing=true
    for key in organic_fields:
        if key=="aim":organic_fields[key].set_pressed_no_signal(l.organic.aim)
        else:organic_fields[key].set_value_no_signal(float(l.organic[key]))
    for key in ["arms","length","taper"]:
        organic_fields[key].editable=l.type=="tendril"
    for key in ["count","gravity"]:
        fields[key].editable=false
    fields.spread.editable=l.type=="tendril"
    fields.collision.disabled=true
    fields.collision.tooltip_text="Визуальная деформация без столкновений"
    organic_hint.text="Размер = ширина. Длина и направление независимы." if l.type=="tendril" else "Размер = радиус массы. Волна меняет её контур."
    syncing=previous

func _organic_change(key: String,value: Variant) -> void:
    if syncing:return
    var l: Dictionary=preset.layers[selected]
    if not l.type in P.ORGANIC_TYPES:return
    l.organic[key]=value
    dirty=true

func _sync_field() -> void:
    if field_panel==null:return
    var l: Dictionary=preset.layers[selected]
    var active: bool=l.type in P.FIELD_TYPES
    field_panel.visible=active
    if not active:return
    var previous: bool=syncing
    syncing=true
    for key in field_parameters:
        if key=="aim":field_parameters[key].set_pressed_no_signal(l.field.aim)
        else:field_parameters[key].set_value_no_signal(float(l.field[key]))
    field_parameters.length.editable=l.type in ["beam","rift"]
    field_parameters.aspect.editable=l.type in ["shockwave","vortex","orb"]
    field_parameters.rotation.editable=l.type!="shockwave"
    field_parameters.distortion.editable=l.type in ["beam","vortex","rift"]
    fields.count.editable=l.type in ["shockwave","vortex","orb"]
    fields.count.tooltip_text="Количество колец или спиралей (до 8)"
    fields.spread.editable=false
    fields.gravity.editable=false
    fields.collision.disabled=true
    fields.collision.tooltip_text="Визуальная форма без столкновений"
    field_hint.text={"shockwave":"Размер = радиус; количество = кольца.","beam":"Размер = ширина; длина ограничивает луч.","vortex":"Размер = радиус; количество = спирали.","orb":"Размер = радиус; количество = орбиты.","rift":"Размер = раскрытие; длина = протяжённость."}.get(l.type,"")
    syncing=previous

func _field_change(key: String,value: Variant) -> void:
    if syncing:return
    var l: Dictionary=preset.layers[selected]
    if not l.type in P.FIELD_TYPES:return
    l.field[key]=value
    dirty=true

func _sync_emitter() -> void:
    if emitter_panel==null:return
    var l: Dictionary=preset.layers[selected]
    var stream: bool=P.is_stream(l)
    var previous: bool=syncing
    syncing=true
    emitter_panel.visible=l.type in P.PARTICLE_TYPES
    emitter_toggle.set_pressed_no_signal(stream)
    emitter_controls.visible=stream
    if fields.has("count"):
        fields.count.editable=not stream
        fields.count.tooltip_text="Для потока задаётся частиц в секунду" if stream else ""
    if fields.has("duration"):
        fields.duration.tooltip_text="Длительность испускания; после неё частицы продолжают жить" if stream else "Длительность слоя"
    if stream:
        for key in emitter_fields:
            if key=="shape":emitter_fields[key].select(P.EMITTER_SHAPES.find(l.emitter.shape))
            else:emitter_fields[key].set_value_no_signal(float(l.emitter[key]))
        _emitter_summary()
    syncing=previous

func _emitter_summary() -> void:
    var l: Dictionary=preset.layers[selected]
    if not P.is_stream(l):return
    emitter_info.text="Испускание: %.2f с. Хвост: до %.2f с. Всего: %d.\nКривые действуют на жизнь каждой частицы."%[float(l.duration),P.max_particle_life(l),P.birth_count(l)]

func _toggle_emitter(enabled: bool) -> void:
    if syncing:return
    var l: Dictionary=preset.layers[selected]
    if not l.type in P.PARTICLE_TYPES:return
    if enabled:
        l.emitter=P.emitter_defaults()
        l.emitter.life=float(l.duration) if float(l.duration)<=3.0 else 3.0
    else:l.erase("emitter")
    _sync_emitter()
    _sync_visibility()
    _sync_curve()
    dirty=true

func _emitter_change(key: String,value: Variant) -> void:
    if syncing:return
    var l: Dictionary=preset.layers[selected]
    if not P.is_stream(l):return
    l.emitter[key]=value
    _emitter_summary()
    dirty=true

func _sync_visibility() -> void:
    var l: Dictionary=preset.layers[selected]
    var particle: bool=l.type in P.PARTICLE_TYPES
    var trail: bool=l.type=="trail"
    var field: bool=l.type in P.FIELD_TYPES
    var organic: bool=l.type in P.ORGANIC_TYPES
    var counts: bool=(particle and not P.is_stream(l)) or l.type=="lightning" or l.type in ["shockwave","vortex","orb"]
    var directional: bool=particle or l.type in ["lightning","slash","tendril"]
    for key in ["speed","end_speed","gravity","collision"]:
        field_rows[key].visible=particle
    field_rows.count.visible=counts
    field_rows.spread.visible=directional
    field_rows.angle.visible=directional or field or organic
    field_rows.follow.visible=not trail
    if field:
        for key in field_parameters:
            if key!="aim":field_parameters[key].get_parent().visible=field_parameters[key].editable
    if organic:
        for key in ["arms","length","taper"]:
            organic_fields[key].get_parent().visible=l.type=="tendril"
    if trail:trail_fields.jitter.get_parent().visible=l.trail.style=="electric"
    if not particle and curve_channel==2:curve_channel=0
    curve_selector.set_item_disabled(2,not particle)
    curve_selector.select(curve_channel)

func _sync_curve() -> void:
    if graph==null:return
    var l: Dictionary=preset.layers[selected]
    var channel: String=P.CHANNELS[curve_channel]
    var custom: bool=P.has_curve(l,channel)
    graph.configure(l.curves[channel] if custom else P.initial_points(l,channel),P.RANGES[channel],custom)
    curve_toggle.text="Вернуть базовую кривую" if custom else "Включить свою кривую"
    _update_curve_controls()
    _update_curve_cursor()

func _update_curve_controls() -> void:
    var l: Dictionary=preset.layers[selected]
    var channel: String=P.CHANNELS[curve_channel]
    var custom: bool=P.has_curve(l,channel)
    for k in ["size","end_size","alpha","end_alpha","speed","end_speed","glow"]:
        if fields.has(k):
            var base: String=k.trim_prefix("end_")
            fields[k].editable=not P.has_curve(l,base) and not ((l.type=="trail" or l.type in P.ORGANIC_TYPES or l.type in P.FIELD_TYPES) and base=="speed")
            fields[k].tooltip_text="Управляется своей кривой" if not fields[k].editable else ""
    var message: String="%d/%d точек. Своя кривая."%[graph.points.size(),P.MAX_POINTS] if custom else "Базовые значения. Включи свою кривую для редактирования."
    if channel=="speed" and l.type not in ["sparks","droplets","smoke"]:
        message+=" Скорость действует только на частицы."
    if P.is_stream(l):message+=" Время жизни одной частицы."
    if l.type=="trail":message+=" Возраст участка следа. Размер = ширина."
    if l.type in P.ORGANIC_TYPES:message+=" Возраст органического эффекта."
    if channel=="alpha":message+=" 1 = непрозрачно."
    curve_status.text=message

func _update_curve_cursor() -> void:
    if graph==null:return
    var l: Dictionary=preset.layers[selected]
    graph.set_cursor(-1.0 if P.is_stream(l) or l.type=="trail" else (time-float(l.start))/float(l.duration))

func _toggle_curve() -> void:
    var l: Dictionary=preset.layers[selected]
    var channel: String=P.CHANNELS[curve_channel]
    if P.has_curve(l,channel):
        l.curves.erase(channel)
        if l.curves.is_empty():l.erase("curves")
    else:
        if not l.has("curves"):l.curves={}
        l.curves[channel]=P.initial_points(l,channel)
    _sync_curve()
    dirty=true

func _curve_changed(points: Array) -> void:
    var l: Dictionary=preset.layers[selected]
    var channel: String=P.CHANNELS[curve_channel]
    if P.has_curve(l,channel) and P.valid_points(channel,points):
        l.curves[channel]=points.duplicate(true)
        _update_curve_controls()
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
    if not catalog_entry.is_empty():
        var saved:Dictionary=CAT.save_draft(catalog_entry,preset,preset.name)
        if saved.is_empty():status.text="Ошибка сохранения";return
        catalog_entry=saved
        status.text="Копия сохранена в общей библиотеке"
        return
    status.text="Сохранено в user://vfx_presets" if P.save_preset(preset) else "Неверный пресет"
    _library()
func _load() -> void:
    if library.selected<0:return
    var value: Dictionary=P.load_preset(P.FOLDER.path_join(library.get_item_text(library.selected)))
    if value.is_empty():status.text="Неверный файл";return
    preset=value
    selected=0
    stage.sweep=false
    for l in preset.layers:
        if l.type=="trail":stage.moving=true;stage.sweep=true;break
    _refresh()
func _process(dt: float) -> void:
    if surface==null:return
    clock+=dt
    if playing and clock>=1.0/30:
        time+=clock
        var end: float=_effect_duration()
        if time>=end:
            if loop:time=fposmod(time,end)
            else:time=end;playing=false
        dirty=true
    if dirty:
        clock=0
        time=minf(time,_effect_duration())
        stage.time=time
        stage.queue_redraw()
        renderer.render(surface.painter,preset,time,{},128,stage.anchor)
        surface.present()
        if compare_labels.visible:
            compare_stage.moving=stage.moving
            compare_stage.sweep=stage.sweep
            compare_stage.bright=stage.bright
            compare_stage.time=time
            compare_stage.queue_redraw()
            if compare_renderer.accelerated!=renderer.accelerated:
                compare_renderer.enable_acceleration(renderer.accelerated)
            compare_renderer.render(compare_surface.painter,reference,time,{},128,compare_stage.anchor)
            compare_surface.present()
        timeline.preset=preset
        timeline.duration_override=_effect_duration()
        timeline.time=time
        timeline.selected=selected
        timeline.queue_redraw()
        _update_curve_cursor()
        syncing=true
        seek.max_value=_effect_duration()
        seek.value=time
        syncing=false
        perf.text="%.2f с | слоёв %d | частиц %d | %.2f мс | %s"%[time,renderer.active_layers,renderer.particles,renderer.render_ms,"C++" if renderer.accelerated else "GDScript"]
        compare_button.tooltip_text=perf.text
        timeline.tooltip_text="ЛКМ — время и слой. Колесо — масштаб. СКМ — сдвиг. "+perf.text
        dirty=false
    play_button.text="Пауза" if playing else "Пуск"
func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo and UI.physical_key(e)==KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
