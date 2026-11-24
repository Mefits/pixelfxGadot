extends Control
const CAT=preload("res://addons/creature/catalog.gd")
var catalog_entry:Dictionary={}
const UI=preload("res://lab/ui_ru.gd")
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VFX=preload("res://addons/pixelfx/composer/preset.gd")
const FX_PREVIEW=preload("res://addons/creature/vfx_preview.gd")
const FX_SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const QUICK=preload("res://lab/vfx_quick_dialog.gd")
const PREVIEW=preload("res://lab/creature_preview.gd")
var rig=RIG.humanoid()
var bank: Dictionary=CLIPS.fighter_bank(0)
var fighter_index: int=0
var copied_pose: Dictionary={}
var fighter_select: OptionButton
var name_id: String="strike"
var pose: Dictionary={}
var time: float=0
var playing: bool=false
var dirty: bool=false
var syncing: bool=false
var preview
var fx_preview=FX_PREVIEW.new()
var fx_surface
var fx_visible: CheckButton
var quick_dialog
var quick_marker: Dictionary={}
var picture: TextureRect
var clip_select: OptionButton
var joint_select: OptionButton
var selected: String="hand_near"
var angle: SpinBox
var duration: SpinBox
var rate: SpinBox
var ease: CheckButton
var loop: CheckButton
var root_x: SpinBox
var root_y: SpinBox
var timeline: Control
var auto_key: CheckButton
var ghost: CheckButton
var drag_offset:=Vector2.ZERO
var edited_pose: bool=false
var history: Array[Dictionary]=[]
var redo_history: Array[Dictionary]=[]
var history_button: Button
var redo_button: Button
var keys: ItemList
var event_list: ItemList
var event_kind: OptionButton
var vfx_select: OptionButton
var vfx_choices: Array=[]
const EVENT_TYPES=["strike","charge","cast","vfx"]
var status: Label
var clock_label: Label
var dragging: bool=false
var rotating: bool=false
var rotation_start: float=0
var rotation_mouse: float=0
var rotation_pivot:=Vector2.ZERO
var confirm: ConfirmationDialog
var pending_action: Callable
var mode_label: Label
var advanced_mode:bool=false
var advanced_controls:Array[Control]=[]
var mode_button:Button
var play_button:Button
var delete_button:Button
var delete_lane:int=0
var shortcut_hint:Label

func _button(parent: Control,label: String,fn: Callable) -> Button:
    var b:=Button.new()
    b.text=label
    parent.add_child(b)
    b.pressed.connect(fn)
    return b

func _label(parent: Control,value: String) -> Label:
    var l:=Label.new()
    l.text=value
    parent.add_child(l)
    return l

func _spin(parent: Control,lo: float,hi: float,step: float,fn: Callable) -> SpinBox:
    var s:=SpinBox.new()
    s.min_value=lo
    s.max_value=hi
    s.step=step
    s.custom_minimum_size.x=0
    s.get_line_edit().custom_minimum_size.x=43
    parent.add_child(s)
    s.value_changed.connect(fn)
    return s

func _ready() -> void:
    var bg:=ColorRect.new()
    bg.color=Color("#101722")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var title:=Label.new()
    title.position=Vector2(16,9)
    title.text="РЕДАКТОР АНИМАЦИЙ"
    title.add_theme_font_size_override("font_size",21)
    add_child(title)
    var view:=SubViewport.new()
    view.size=Vector2i(144,108)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(view)
    preview=PREVIEW.new()
    preview.rig=rig
    view.add_child(preview)
    fx_surface=FX_SURFACE.new()
    view.add_child(fx_surface)
    fx_surface.configure(144,108)
    fx_preview.renderer.enable_acceleration()
    picture=TextureRect.new()
    picture.position=Vector2(40,44)
    picture.size=Vector2(528,396)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    picture.texture=view.get_texture()
    add_child(picture)
    picture.gui_input.connect(_drag)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(604,44)
    scroll.size=Vector2(344,430)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var side:=VBoxContainer.new()
    side.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(side)
    var compact:=Theme.new()
    compact.default_font_size=13
    side.theme=compact
    side.add_theme_constant_override("separation",3)
    var top:=HBoxContainer.new()
    side.add_child(top)
    clip_select=OptionButton.new()
    clip_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    top.add_child(clip_select)
    for n in CLIPS.NAMES: clip_select.add_item(UI.label(n))
    clip_select.select(CLIPS.NAMES.find(name_id))
    clip_select.item_selected.connect(func(i:int): _choose(CLIPS.NAMES[i]))
    _button(top,"В бой",func(): _go("res://lab/combat_lab.tscn"))
    var choose_fighter:=HBoxContainer.new()
    side.add_child(choose_fighter)
    fighter_select=OptionButton.new()
    fighter_select.add_item("1 / Синий")
    fighter_select.add_item("2 / Рыжий")
    fighter_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    choose_fighter.add_child(fighter_select)
    fighter_select.item_selected.connect(_switch_fighter)
    _button(choose_fighter,"Копия",func():copied_pose=pose.duplicate(true))
    _button(choose_fighter,"Вставить",func():
        if not copied_pose.is_empty():pose=copied_pose.duplicate(true);_edit())
    advanced_controls.append(choose_fighter)
    _label(side,"1. Анимация и длительность")
    var timings:=HBoxContainer.new()
    side.add_child(timings)
    _label(timings,"Длит., с")
    duration=_spin(timings,.1,10,.01,_set_duration)
    _label(timings,"Кадр/с")
    rate=_spin(timings,1,60,1,func(_v:float):pass)
    rate.value=30
    advanced_controls.append(rate)
    advanced_controls.append(timings.get_child(2))
    var toggles:=HBoxContainer.new()
    side.add_child(toggles)
    ease=CheckButton.new()
    ease.text="Плавно"
    toggles.add_child(ease)
    ease.toggled.connect(func(v:bool):
        if not syncing:
            _remember()
            bank[name_id]["easing"]="smooth" if v else "linear"
            dirty=true)
    loop=CheckButton.new()
    loop.text="Цикл"
    toggles.add_child(loop)
    loop.toggled.connect(func(v:bool):
        if not syncing:
            _remember()
            bank[name_id]["loop"]=v
            dirty=true)
    _label(side,"2. Выбери сустав и измени позу")
    joint_select=OptionButton.new()
    side.add_child(joint_select)
    for j in rig.joints: joint_select.add_item(UI.label(j.id))
    joint_select.select(rig.ids[selected])
    joint_select.item_selected.connect(func(i:int):selected=rig.joints[i].id;_sync())
    var controls:=HBoxContainer.new()
    side.add_child(controls)
    _label(controls,"Угол")
    angle=_spin(controls,-180,180,1,func(v:float):
        if not syncing: pose.angles[selected]=v; _edit())
    _label(controls,"X/Y")
    root_x=_spin(controls,-40,40,.5,func(v:float):
        if not syncing: pose.root[0]=v; _edit())
    root_y=_spin(controls,-40,40,.5,func(v:float):
        if not syncing: pose.root[1]=v; _edit())
    var pose_actions:=HBoxContainer.new()
    side.add_child(pose_actions)
    var mirror:=_button(pose_actions,"Зеркало",_mirror_pose)
    mirror.tooltip_text="Поменять ближние и дальние конечности и отразить углы"
    _button(pose_actions,"Угол 0",_zero_joint)
    advanced_controls.append(_button(pose_actions,"Чистый клип",_ask_blank))
    mode_label=_label(side,"ЛКМ: перемещение · ПКМ: вращение выбранного сустава")
    mode_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var aids:=HBoxContainer.new()
    side.add_child(aids)
    auto_key=CheckButton.new()
    auto_key.text="Автоключ"
    auto_key.button_pressed=true
    auto_key.tooltip_text="Записывать позу после перетаскивания или изменения параметра"
    aids.add_child(auto_key)
    ghost=CheckButton.new()
    ghost.text="Соседние позы"
    ghost.button_pressed=true
    aids.add_child(ghost)
    ghost.toggled.connect(func(_v:bool):_sync())
    var actions:=HBoxContainer.new()
    actions.position=Vector2(16,443)
    actions.size=Vector2(576,32)
    actions.theme=compact
    add_child(actions)
    var store:=_button(actions,"+ Ключ",_key)
    UI.action_button(store,"Записать ключ (K)",true)
    delete_button=_button(actions,"Удалить",_delete_selected)
    UI.action_button(delete_button,"Удалить выбранный ключ или событие")
    play_button=_button(actions,"Пуск (Space)",_play)
    UI.action_button(play_button,"Пуск / пауза (Space)",true)
    UI.action_button(_button(actions,"Сначала",func():_seek(0)),"В начало (Home)")
    var nav:=HBoxContainer.new()
    actions.add_child(nav)
    _button(nav,"◀",func():_adjacent(-1)).tooltip_text="Предыдущий ключ"
    _button(nav,"▶",func():_adjacent(1)).tooltip_text="Следующий ключ"
    history_button=_button(nav,"↶",_undo)
    redo_button=_button(nav,"↷",_redo)
    history_button.tooltip_text="Отменить изменение клипа"
    redo_button.tooltip_text="Повторить изменение клипа"
    keys=ItemList.new()
    keys.custom_minimum_size.y=48
    side.add_child(keys)
    keys.item_selected.connect(func(i:int):
        delete_lane=0
        event_list.deselect_all()
        _seek(float(bank[name_id].keys[i].t))
        _update_transport())
    var advanced_start:int=side.get_child_count()
    _label(side,"3. События атаки и эффектов")
    var preview_row:=HBoxContainer.new()
    side.add_child(preview_row)
    fx_visible=CheckButton.new()
    fx_visible.text="Показать VFX"
    fx_visible.button_pressed=true
    preview_row.add_child(fx_visible)
    fx_visible.toggled.connect(func(_v:bool):_draw_vfx())
    _button(preview_row,"− кадр",func():_seek(time-1.0/rate.value))
    _button(preview_row,"+ кадр",func():_seek(time+1.0/rate.value))
    var erow:=HBoxContainer.new()
    side.add_child(erow)
    event_kind=OptionButton.new()
    for n in EVENT_TYPES:event_kind.add_item(UI.label(n))
    erow.add_child(event_kind)
    _button(erow,"Добавить",_add_event)
    _button(erow,"Удалить",_delete_event)
    event_list=ItemList.new()
    event_list.custom_minimum_size.y=48
    side.add_child(event_list)
    event_list.item_selected.connect(_event_selected)
    vfx_select=OptionButton.new()
    vfx_select.fit_to_longest_item=false
    vfx_select.clip_text=true
    vfx_select.tooltip_text="Пресет для нового VFX-маркера"
    side.add_child(vfx_select)
    var vfx_actions:=HBoxContainer.new()
    side.add_child(vfx_actions)
    _button(vfx_actions,"+ VFX",_add_vfx_event)
    _button(vfx_actions,"Заменить",_replace_vfx_event)
    _button(vfx_actions,"Обновить список",_refresh_vfx_library)
    _refresh_vfx_library()
    _button(side,"Быстрая настройка выбранного VFX",_quick_open)
    for i in range(advanced_start,side.get_child_count()):advanced_controls.append(side.get_child(i))
    quick_dialog=QUICK.new()
    add_child(quick_dialog)
    quick_dialog.applied.connect(_quick_apply)
    var save:=HBoxContainer.new()
    save.position=Vector2(604,9)
    save.theme=compact
    add_child(save)
    UI.action_button(_button(save,"Сохранить",_save),"Сохранить (Ctrl+S)",true)
    UI.action_button(_button(save,"Загрузить",_ask_load),"Загрузить сохранённое")
    advanced_controls.append(_button(save,"Сброс",_ask_default))
    UI.action_button(_button(save,"Меню",func():_go("res://lab/main.tscn")),"Главное меню (Esc)")
    mode_button=_button(self,"Простой ▾",_toggle_mode)
    mode_button.position=Vector2(388,8)
    mode_button.size=Vector2(196,30)
    UI.action_button(mode_button,"Показать или скрыть технические параметры")
    timeline=preload("res://lab/pose_timeline.gd").new()
    timeline.position=Vector2(18,478)
    timeline.size=Vector2(922,40)
    timeline.step=1.0/60
    add_child(timeline)
    timeline.value_changed.connect(func(v:float):
        if not syncing: _seek(v))
    timeline.marker_moved.connect(_move_marker)
    timeline.marker_selected.connect(func(lane:int,i:int):
        delete_lane=lane
        timeline.selected_lane=lane
        timeline.selected_index=i
        if lane==0:
            keys.select(i)
            event_list.deselect_all()
        else:
            keys.deselect_all()
            event_list.select(i)
        _update_transport())
    clock_label=Label.new()
    clock_label.position=Vector2(18,520)
    add_child(clock_label)
    status=Label.new()
    status.position=Vector2(190,520)
    status.size=Vector2(750,19)
    status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    status.add_theme_font_size_override("font_size",13)
    status.text="Перетащи кисть, стопу или таз. Автоключ запишет позу."
    add_child(status)
    confirm=ConfirmationDialog.new()
    confirm.title="Подтверждение"
    confirm.ok_button_text="Продолжить"
    confirm.cancel_button_text="Отмена"
    add_child(confirm)
    confirm.confirmed.connect(func():
        if pending_action.is_valid():pending_action.call())
    catalog_entry=CAT.consume(get_tree(),"animation")
    if not catalog_entry.is_empty():
        name_id=catalog_entry.payload.slot
        bank[name_id]=catalog_entry.payload.clip.duplicate(true)
        clip_select.select(CLIPS.NAMES.find(name_id))
        clip_select.disabled=true
        fighter_select.disabled=true
        status.text="Шаблон библиотеки: отдельная копия, не банк бойца."
    _choose(name_id)
    advanced_mode=UI.advanced("animation")
    _apply_mode()

func _choose(n: String) -> void:
    name_id=n
    history.clear()
    redo_history.clear()
    playing=false
    _seek(0)
    _refresh_lists()

func _seek(v: float) -> void:
    playing=false
    edited_pose=false
    time=clampf(v,0,float(bank[name_id].duration))
    delete_lane=0
    if keys!=null:
        keys.deselect_all()
        event_list.deselect_all()
        for i in range(bank[name_id].keys.size()):
            if absf(float(bank[name_id].keys[i].t)-time)<.0001:keys.select(i);break
    if timeline!=null:
        timeline.selected_lane=-1
        timeline.selected_index=-1
    pose=CLIPS.sample(bank[name_id],time,false)
    _sync()

func _sync() -> void:
    rig.evaluate(pose)
    preview.selected=selected
    preview.ghost_poses=[]
    if ghost!=null and ghost.button_pressed and not playing:
        var prior: Dictionary={}
        var next: Dictionary={}
        for key in bank[name_id].keys:
            if float(key.t)<time-.0001:prior=key.pose
            elif float(key.t)>time+.0001:
                next=key.pose
                break
        if not prior.is_empty():preview.ghost_poses.append({"pose":prior,"color":Color("#52778b")})
        if not next.is_empty():preview.ghost_poses.append({"pose":next,"color":Color("#8b6d50")})
    preview.queue_redraw()
    _draw_vfx()
    syncing=true
    timeline.max_value=float(bank[name_id].duration)
    timeline.clip=bank[name_id]
    timeline.value=time
    duration.value=float(bank[name_id].duration)
    ease.button_pressed=bank[name_id].get("easing","smooth")=="smooth"
    loop.button_pressed=bank[name_id].loop
    angle.value=float(pose.angles.get(selected,0))
    root_x.value=float(pose.root[0])
    root_y.value=float(pose.root[1])
    joint_select.select(rig.ids[selected])
    clock_label.text="%.3f / %.2f с"%[time,bank[name_id].duration]
    syncing=false
    _update_history()
    _update_transport()

func _draw_vfx() -> void:
    if fx_surface==null or fx_visible==null:return
    fx_surface.visible=fx_visible.button_pressed
    if not fx_surface.visible:return
    var sample_time: float=time
    if playing:sample_time=minf(float(bank[name_id].duration),floor(time*rate.value+.00001)/rate.value)
    fx_preview.draw(fx_surface.painter,bank[name_id],sample_time,preview.origin,preview.origin+Vector2(40,-26))
    fx_surface.present()

func _quick_open() -> void:
    var rows: PackedInt32Array=event_list.get_selected_items()
    if rows.is_empty():
        status.text="Выбери фиолетовый VFX-маркер."
        return
    var event: Dictionary=bank[name_id].events[rows[0]]
    if event.kind!="vfx":
        status.text="Быстрая настройка доступна для VFX-маркеров."
        return
    playing=false
    quick_marker=event
    quick_dialog.open_for(event.preset)

func _quick_apply(value: Dictionary) -> void:
    var index: int=bank[name_id].events.find(quick_marker)
    if index<0 or not VFX.valid(value):return
    _remember()
    quick_marker.preset=value
    dirty=true
    _refresh_lists()
    event_list.select(index)
    _draw_vfx()
    status.text="Эффект настроен. Ctrl+Z — отменить."
    quick_marker={}

func _edit() -> void:
    playing=false
    edited_pose=true
    status.text="Поза изменена. Запиши ключ, чтобы сохранить её."
    _sync()
    if auto_key.button_pressed and not dragging and not rotating:_key()

func _drag(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT:
        if not e.pressed:
            if rotating and edited_pose and auto_key.button_pressed:_key()
            rotating=false
            return
        playing=false
        rotation_pivot=rig.point(selected)
        var mouse: Vector2=e.position/(picture.size.x/144.0)-preview.origin-rotation_pivot
        rotating=mouse.length()>1
        rotation_mouse=mouse.angle()
        rotation_start=float(pose.angles.get(selected,0))
        return
    if e is InputEventMouseMotion and rotating:
        var mouse: Vector2=e.position/(picture.size.x/144.0)-preview.origin-rotation_pivot
        if mouse.length()>1:
            pose.angles[selected]=wrapf(rotation_start+rad_to_deg(wrapf(mouse.angle()-rotation_mouse,-PI,PI)),-180,180)
            _edit()
        return
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        if not e.pressed:
            if dragging and edited_pose and auto_key.button_pressed:_key()
            dragging=false
            return
        playing=false
        var target: Vector2=e.position/(picture.size.x/144.0)-preview.origin
        var nearest: float=5.5
        var picked: String=""
        for j in rig.joints:
            var d: float=rig.point(j.id).distance_to(target)
            if d<nearest:
                nearest=d
                picked=j.id
        dragging=not picked.is_empty()
        if dragging:
            selected=picked
            drag_offset=rig.point(selected)-target
            _sync()
    elif e is InputEventMouseMotion and dragging:
        var target: Vector2=e.position/(picture.size.x/144.0)-preview.origin+drag_offset
        if selected=="hips":
            var delta: Vector2=target-rig.point("hips")
            pose.root[0]=clampf(float(pose.root[0])+delta.x,-40,40)
            pose.root[1]=clampf(float(pose.root[1])+delta.y,-40,40)
        else:pose=rig.solve_ik(pose,selected,target)
        _edit()

func _key() -> void:
    _remember()
    CLIPS.put_key(bank[name_id],time,pose)
    edited_pose=false
    dirty=true
    _refresh_lists()
    _sync()
    status.text="Ключ записан: %.3f с"%time

func _delete_key() -> void:
    var rows: PackedInt32Array=keys.get_selected_items()
    if rows.size()>0 and bank[name_id].keys.size()>1:
        _remember()
        bank[name_id].keys.remove_at(rows[0])
        dirty=true
        _seek(time)
        _refresh_lists()

func _set_duration(v: float) -> void:
    if syncing:return
    _remember()
    var c: Dictionary=bank[name_id]
    var scale: float=v/float(c.duration)
    for k in c.keys:k.t=float(k.t)*scale
    for e in c.events:e.t=float(e.t)*scale
    c.duration=v
    dirty=true
    _seek(time*scale)
    _refresh_lists()

func _refresh_vfx_library() -> void:
    vfx_choices.clear()
    vfx_select.clear()
    for i in range(12):
        var p: Dictionary=VFX.demo(i)
        vfx_choices.append(p)
        vfx_select.add_item("Демо: "+UI.label(p.name))
    var dir:=DirAccess.open(VFX.FOLDER)
    if dir!=null:
        for file in dir.get_files():
            if not file.ends_with(".json"):continue
            var p: Dictionary=VFX.load_preset(VFX.FOLDER.path_join(file))
            if p.is_empty():continue
            vfx_choices.append(p)
            vfx_select.add_item("Свой: "+p.name)
    if not vfx_choices.is_empty():vfx_select.select(0)

func _event_selected(index: int) -> void:
    var events: Array=bank[name_id].events
    if index<0 or index>=events.size():return
    var e: Dictionary=events[index]
    selected=e.anchor if rig.ids.has(e.anchor) else selected
    event_kind.select(EVENT_TYPES.find(e.kind))
    _seek(float(e.t))
    delete_lane=1
    keys.deselect_all()
    event_list.select(index)
    timeline.selected_lane=1
    timeline.selected_index=index
    timeline.queue_redraw()
    _update_transport()
    if e.kind=="vfx":status.text="VFX: "+str(e.preset.name)+" · "+UI.label(e.anchor)

func _add_vfx_event() -> void:
    var c: Dictionary=bank[name_id]
    var count: int=0
    for e in c.events:
        if e.kind=="vfx":count+=1
    if count>=CLIPS.MAX_VFX_MARKERS:
        status.text="Лимит VFX-маркеров: "+str(CLIPS.MAX_VFX_MARKERS)
        return
    if vfx_select.selected<0:return
    _remember()
    var marker: Dictionary={"t":time,"kind":"vfx","anchor":selected,"preset":vfx_choices[vfx_select.selected].duplicate(true)}
    c.events.append(marker)
    c.events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    dirty=true
    _refresh_lists()
    event_list.select(c.events.find(marker))
    status.text="VFX добавлен: "+str(marker.preset.name)

func _replace_vfx_event() -> void:
    var rows: PackedInt32Array=event_list.get_selected_items()
    if rows.is_empty() or vfx_select.selected<0:return
    var marker: Dictionary=bank[name_id].events[rows[0]]
    if marker.kind!="vfx":
        status.text="Выбери VFX-маркер для замены."
        return
    _remember()
    marker.preset=vfx_choices[vfx_select.selected].duplicate(true)
    marker.anchor=selected
    dirty=true
    _refresh_lists()
    event_list.select(rows[0])
    status.text="VFX заменён: "+str(marker.preset.name)

func _add_event() -> void:
    if EVENT_TYPES[event_kind.selected]=="vfx":
        _add_vfx_event()
        return
    _remember()
    var c: Dictionary=bank[name_id]
    c.events.append({"t":time,"kind":EVENT_TYPES[event_kind.selected],"anchor":selected})
    c.events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    dirty=true
    _refresh_lists()

func _delete_event() -> void:
    var rows: PackedInt32Array=event_list.get_selected_items()
    if rows.size()>0:
        _remember()
        bank[name_id].events.remove_at(rows[0])
        dirty=true
        _refresh_lists()

func _refresh_lists() -> void:
    delete_lane=0
    timeline.selected_lane=-1
    timeline.selected_index=-1
    keys.clear()
    event_list.clear()
    for k in bank[name_id].keys:
        keys.add_item("Ключ  %.3f с"%k.t)
        if absf(float(k.t)-time)<.0001:keys.select(keys.item_count-1)
    for e in bank[name_id].events:
        var label_text: String=str(e.preset.name) if e.kind=="vfx" else UI.label(e.kind)
        event_list.add_item("%.3f  %s @ %s"%[e.t,label_text,UI.label(e.anchor)])
        if e.kind=="vfx":event_list.set_item_custom_fg_color(event_list.item_count-1,Color("#c5a1ff"))
    timeline.clip=bank[name_id]
    timeline.queue_redraw()
    _draw_vfx()
    _update_history()

func _path() -> String:
    return CLIPS.SAVE_PATH if fighter_index==0 else CLIPS.SECOND_PATH

func _switch_fighter(i: int) -> void:
    if dirty and not CLIPS.save_bank(bank,_path()):
        fighter_select.select(fighter_index)
        status.text="Ошибка сохранения. Боец не переключён."
        return
    fighter_index=i
    bank=CLIPS.fighter_bank(i)
    preview.tint=Color("#5aafdc") if i==0 else Color("#ce775f")
    dirty=false
    _choose(name_id)

func _save_draft()->bool:
    var value:Dictionary=CAT.save_draft(catalog_entry,{"slot":name_id,"clip":bank[name_id]})
    if value.is_empty():return false
    catalog_entry=value
    dirty=false
    return true

func _save() -> void:
    if not catalog_entry.is_empty():
        status.text="Копия сохранена в библиотеке" if _save_draft() else "Ошибка сохранения"
        return
    if CLIPS.save_bank(bank,_path()):
        dirty=false
        status.text="Сохранено: "+ProjectSettings.globalize_path(_path())
    else:
        status.text="Ошибка: неверные данные анимации."

func _go(path: String) -> void:
    if dirty:
        var ok:bool=_save_draft() if not catalog_entry.is_empty() else CLIPS.save_bank(bank,_path())
        if not ok:
            status.text="Не удалось сохранить. Проверь данные анимации."
            return
    get_tree().change_scene_to_file(path)

func _play() -> void:
    playing=not playing
    if playing and time>=float(bank[name_id].duration):time=0
    _sync()

func _input(e:InputEvent)->void:
    if not UI.editor_shortcut(self,e):return
    var key:Key=UI.physical_key(e)
    if e.ctrl_pressed:
        match key:
            KEY_S:_save()
            KEY_Z:
                if e.shift_pressed:_redo()
                else:_undo()
            KEY_Y:_redo()
            KEY_C:copied_pose=pose.duplicate(true)
            KEY_V:
                if not copied_pose.is_empty():pose=copied_pose.duplicate(true);_edit()
            _ :return
    else:
        match key:
            KEY_ESCAPE:_go("res://lab/main.tscn")
            KEY_SPACE:_play()
            KEY_DELETE:_delete_selected()
            KEY_HOME:_seek(0)
            KEY_K:_key()
            KEY_LEFT:_seek(time-1.0/rate.value)
            KEY_RIGHT:_seek(time+1.0/rate.value)
            _ :return
    get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
    if not playing:return
    time+=dt
    var d: float=bank[name_id].duration
    if time>=d:
        if bank[name_id].loop:time=fposmod(time,d)
        else:time=d;playing=false
    pose=CLIPS.sample(bank[name_id],d if not playing and time>=d else minf(d,floor(time*rate.value+.00001)/rate.value),false)
    _sync()

func _adjacent(direction: int) -> void:
    var arr: Array=bank[name_id].keys
    if direction>0:
        for k in arr:
            if float(k.t)>time+.0001:_seek(k.t);_refresh_lists();return
    else:
        for i in range(arr.size()-1,-1,-1):
            if float(arr[i].t)<time-.0001:_seek(arr[i].t);_refresh_lists();return

func _remember() -> void:
    history.append(bank[name_id].duplicate(true))
    if history.size()>80:history.pop_front()
    redo_history.clear()
    _update_history()

func _update_history() -> void:
    if history_button!=null:history_button.disabled=history.is_empty()
    if redo_button!=null:redo_button.disabled=redo_history.is_empty()

func _undo() -> void:
    if history.is_empty():return
    redo_history.append(bank[name_id].duplicate(true))
    bank[name_id]=history.pop_back()
    dirty=true
    _seek(time)
    _refresh_lists()

func _redo() -> void:
    if redo_history.is_empty():return
    history.append(bank[name_id].duplicate(true))
    bank[name_id]=redo_history.pop_back()
    dirty=true
    _seek(time)
    _refresh_lists()

func _move_marker(lane: int,index: int,t: float) -> void:
    var c: Dictionary=bank[name_id]
    var arr: Array=c.keys if lane==0 else c.events
    if index<0 or index>=arr.size():return
    t=clampf(t,0,float(c.duration))
    if absf(float(arr[index].t)-t)<.0001:return
    if lane==0:
        for i in range(arr.size()):
            if i!=index and absf(float(arr[i].t)-t)<.0001:
                status.text="На этом времени уже есть ключ. Перемещение отменено."
                return
    _remember()
    var item: Dictionary=arr[index]
    item.t=t
    arr.sort_custom(func(a,b):return float(a.t)<float(b.t))
    dirty=true
    _seek(t)
    _refresh_lists()
    delete_lane=lane
    if lane==1:
        keys.deselect_all()
        event_list.select(arr.find(item))
        timeline.selected_lane=1
        timeline.selected_index=arr.find(item)
        timeline.queue_redraw()
    _update_transport()
    status.text="Маркер перемещён: %.3f с"%t

func _mirror_pose() -> void:
    var a: Dictionary={}
    for id in pose.angles:
        var dest: String=str(id)
        if dest.ends_with("_near"):dest=dest.trim_suffix("_near")+"_far"
        elif dest.ends_with("_far"):dest=dest.trim_suffix("_far")+"_near"
        a[dest]=-pose.angles[id]
    pose={"angles":a,"root":[-pose.root[0],pose.root[1]]}
    _edit()

func _zero_joint() -> void:
    pose.angles[selected]=0.0
    _edit()

func _ask(message: String,action: Callable) -> void:
    pending_action=action
    confirm.dialog_text=message
    confirm.popup_centered(Vector2i(400,140))

func _ask_blank() -> void:
    _ask("Очистить только текущую анимацию? Можно отменить через Ctrl+Z.",_blank_clip)

func _blank_clip() -> void:
    _remember()
    var c: Dictionary=bank[name_id]
    var d: float=c.duration
    var neutral: Dictionary=CLIPS.sample(CLIPS.defaults().idle,0,false)
    c.keys=[{"t":0.0,"pose":neutral.duplicate(true)},{"t":d,"pose":neutral.duplicate(true)}]
    c.events=[]
    dirty=true
    _seek(0)
    _refresh_lists()
    status.text="Чистый клип. Выбери время и измени позу."

func _ask_default() -> void:
    _ask("Восстановить исходную версию только текущего клипа?",func():
        _remember()
        bank[name_id]=CLIPS.defaults()[name_id].duplicate(true)
        dirty=true
        _seek(0)
        _refresh_lists())

func _ask_load() -> void:
    if not catalog_entry.is_empty():
        _ask("Восстановить последний сохранённый шаблон?",func():
            bank[name_id]=catalog_entry.payload.clip.duplicate(true)
            _choose(name_id)
            dirty=false)
        return
    _ask("Загрузить сохранённые анимации бойца? Несохранённые правки будут потеряны.",func():
        bank=CLIPS.fighter_bank(fighter_index)
        _choose(name_id)
        dirty=false)

func _delete_selected()->void:
    if delete_lane==1:
        if event_list.get_selected_items().is_empty():return
        _delete_event()
        status.text="Событие удалено. Ctrl+Z — отменить."
    else:
        if keys.get_selected_items().is_empty():return
        if bank[name_id].keys.size()<=1:
            status.text="Последний ключ удалить нельзя."
            return
        _delete_key()
        status.text="Ключ удалён. Ctrl+Z — отменить."
    _update_transport()
func _update_transport()->void:
    if play_button!=null:play_button.text="Пауза" if playing else "Пуск"
    if delete_button!=null and keys!=null and event_list!=null:
        delete_button.disabled=event_list.get_selected_items().is_empty() if delete_lane==1 else (keys.get_selected_items().is_empty() or bank[name_id].keys.size()<=1)
func _toggle_mode()->void:
    advanced_mode=not advanced_mode
    UI.set_advanced("animation",advanced_mode)
    _apply_mode()
func _apply_mode()->void:
    for control in advanced_controls:control.visible=advanced_mode
    mode_button.text="Расширенный ▾" if advanced_mode else "Простой ▾"
    status.text="Все параметры и события доступны" if advanced_mode else "Простой: поза, ключи, время. События и VFX — в расширенном."
    _update_transport()
