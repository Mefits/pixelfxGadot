extends Control
const UI=preload("res://lab/ui_ru.gd")
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
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
    title.text="РЕДАКТОР АНИМАЦИЙ / позы и ключи"
    title.add_theme_font_size_override("font_size",21)
    add_child(title)
    var view:=SubViewport.new()
    view.size=Vector2i(144,108)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(view)
    preview=PREVIEW.new()
    preview.rig=rig
    view.add_child(preview)
    picture=TextureRect.new()
    picture.position=Vector2(16,44)
    picture.size=Vector2(576,432)
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
    _label(side,"1. Анимация и длительность")
    var timings:=HBoxContainer.new()
    side.add_child(timings)
    _label(timings,"Длит., с")
    duration=_spin(timings,.1,10,.01,_set_duration)
    _label(timings,"Кадр/с")
    rate=_spin(timings,1,60,1,func(_v:float):pass)
    rate.value=30
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
    _button(pose_actions,"Чистый клип",_ask_blank)
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
    side.add_child(actions)
    var store:=_button(actions,"Записать ключ",_key)
    store.tooltip_text="Сохраняет текущую позу в выбранный момент времени"
    _button(actions,"Удалить",_delete_key)
    _button(actions,"Пуск/пауза",_play)
    var nav:=HBoxContainer.new()
    side.add_child(nav)
    _button(nav,"◀ Ключ",func():_adjacent(-1))
    _button(nav,"Ключ ▶",func():_adjacent(1))
    history_button=_button(nav,"↶",_undo)
    redo_button=_button(nav,"↷",_redo)
    history_button.tooltip_text="Отменить изменение клипа"
    redo_button.tooltip_text="Повторить изменение клипа"
    keys=ItemList.new()
    keys.custom_minimum_size.y=48
    side.add_child(keys)
    keys.item_selected.connect(func(i:int): _seek(float(bank[name_id].keys[i].t)))
    _label(side,"3. События атаки и эффектов")
    var erow:=HBoxContainer.new()
    side.add_child(erow)
    event_kind=OptionButton.new()
    for n in ["strike","charge","cast"]:event_kind.add_item(UI.label(n))
    erow.add_child(event_kind)
    _button(erow,"Добавить",_add_event)
    _button(erow,"Удалить",_delete_event)
    event_list=ItemList.new()
    event_list.custom_minimum_size.y=48
    side.add_child(event_list)
    var save:=HBoxContainer.new()
    save.position=Vector2(604,9)
    save.theme=compact
    add_child(save)
    _button(save,"Сохранить",_save)
    _button(save,"Загрузить",_ask_load)
    _button(save,"Сброс клипа",_ask_default)
    _button(save,"Выход",func():_go("res://lab/main.tscn"))
    timeline=preload("res://lab/pose_timeline.gd").new()
    timeline.position=Vector2(18,478)
    timeline.size=Vector2(922,40)
    timeline.step=1.0/60
    add_child(timeline)
    timeline.value_changed.connect(func(v:float):
        if not syncing: _seek(v))
    timeline.marker_moved.connect(_move_marker)
    timeline.marker_selected.connect(func(lane:int,i:int):
        if lane==0:keys.select(i)
        else:event_list.select(i))
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
    _choose(name_id)

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
        var mouse: Vector2=e.position/4-preview.origin-rotation_pivot
        rotating=mouse.length()>1
        rotation_mouse=mouse.angle()
        rotation_start=float(pose.angles.get(selected,0))
        return
    if e is InputEventMouseMotion and rotating:
        var mouse: Vector2=e.position/4-preview.origin-rotation_pivot
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
        var target: Vector2=e.position/4-preview.origin
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
        var target: Vector2=e.position/4-preview.origin+drag_offset
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

func _add_event() -> void:
    _remember()
    var c: Dictionary=bank[name_id]
    c.events.append({"t":time,"kind":["strike","charge","cast"][event_kind.selected],"anchor":selected})
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
    keys.clear()
    event_list.clear()
    for k in bank[name_id].keys:
        keys.add_item("Ключ  %.3f с"%k.t)
        if absf(float(k.t)-time)<.0001:keys.select(keys.item_count-1)
    for e in bank[name_id].events:event_list.add_item("%.3f  %s @ %s"%[e.t,UI.label(e.kind),UI.label(e.anchor)])
    timeline.clip=bank[name_id]
    timeline.queue_redraw()
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

func _save() -> void:
    if CLIPS.save_bank(bank,_path()):
        dirty=false
        status.text="Сохранено: "+ProjectSettings.globalize_path(_path())
    else:
        status.text="Ошибка: неверные данные анимации."

func _go(path: String) -> void:
    if dirty and not CLIPS.save_bank(bank,_path()):
        status.text="Не удалось сохранить. Проверь данные анимации."
        return
    get_tree().change_scene_to_file(path)

func _play() -> void:
    playing=not playing
    if playing and time>=float(bank[name_id].duration):time=0
    _sync()

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        if UI.physical_key(e)==KEY_ESCAPE:_go("res://lab/main.tscn")
        elif UI.physical_key(e)==KEY_SPACE:_play()
        elif e.ctrl_pressed and UI.physical_key(e)==KEY_Z:_undo()
        elif e.ctrl_pressed and UI.physical_key(e)==KEY_Y:_redo()

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
    if lane==1:event_list.select(arr.find(item))
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
    _ask("Загрузить сохранённые анимации бойца? Несохранённые правки будут потеряны.",func():
        bank=CLIPS.fighter_bank(fighter_index)
        _choose(name_id)
        dirty=false)
