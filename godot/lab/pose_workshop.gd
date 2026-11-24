extends Control
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
var timeline: HSlider
var keys: ItemList
var event_list: ItemList
var event_kind: OptionButton
var status: Label
var clock_label: Label
var dragging: bool=false

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
    title.text="POSE WORKSHOP / keyframes + IK + event markers"
    title.add_theme_font_size_override("font_size",21)
    add_child(title)
    var view:=SubViewport.new()
    view.size=Vector2i(192,144)
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
    var side:=VBoxContainer.new()
    side.position=Vector2(608,44)
    side.size=Vector2(336,428)
    side.add_theme_constant_override("separation",3)
    add_child(side)
    var top:=HBoxContainer.new()
    side.add_child(top)
    clip_select=OptionButton.new()
    clip_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    top.add_child(clip_select)
    for n in CLIPS.NAMES: clip_select.add_item(n)
    clip_select.select(CLIPS.NAMES.find(name_id))
    clip_select.item_selected.connect(func(i:int): _choose(CLIPS.NAMES[i]))
    _button(top,"Arena",func(): _go("res://lab/combat_lab.tscn"))
    var choose_fighter:=HBoxContainer.new()
    side.add_child(choose_fighter)
    fighter_select=OptionButton.new()
    fighter_select.add_item("Fighter 1 / Azure")
    fighter_select.add_item("Fighter 2 / Ember")
    fighter_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    choose_fighter.add_child(fighter_select)
    fighter_select.item_selected.connect(_switch_fighter)
    _button(choose_fighter,"Copy pose",func():copied_pose=pose.duplicate(true))
    _button(choose_fighter,"Paste",func():
        if not copied_pose.is_empty():pose=copied_pose.duplicate(true);_edit())
    var timings:=HBoxContainer.new()
    side.add_child(timings)
    _label(timings,"Seconds")
    duration=_spin(timings,.1,10,.05,_set_duration)
    _label(timings,"Rate")
    rate=_spin(timings,1,60,1,func(_v:float):pass)
    rate.value=30
    var toggles:=HBoxContainer.new()
    side.add_child(toggles)
    ease=CheckButton.new()
    ease.text="Smooth"
    toggles.add_child(ease)
    ease.toggled.connect(func(v:bool):
        if not syncing: bank[name_id]["easing"]="smooth" if v else "linear"; dirty=true)
    loop=CheckButton.new()
    loop.text="Loop"
    toggles.add_child(loop)
    loop.toggled.connect(func(v:bool):
        if not syncing: bank[name_id]["loop"]=v; dirty=true)
    joint_select=OptionButton.new()
    side.add_child(joint_select)
    for j in rig.joints: joint_select.add_item(j.id)
    joint_select.select(rig.ids[selected])
    joint_select.item_selected.connect(func(i:int):selected=rig.joints[i].id;_sync())
    var controls:=HBoxContainer.new()
    side.add_child(controls)
    _label(controls,"Angle")
    angle=_spin(controls,-180,180,1,func(v:float):
        if not syncing: pose.angles[selected]=v; _edit())
    _label(controls,"Root")
    root_x=_spin(controls,-40,40,.5,func(v:float):
        if not syncing: pose.root[0]=v; _edit())
    root_y=_spin(controls,-40,40,.5,func(v:float):
        if not syncing: pose.root[1]=v; _edit())
    var actions:=HBoxContainer.new()
    side.add_child(actions)
    _button(actions,"Set key",_key)
    _button(actions,"Delete key",_delete_key)
    _button(actions,"Play / pause",_play)
    keys=ItemList.new()
    keys.custom_minimum_size.y=64
    side.add_child(keys)
    keys.item_selected.connect(func(i:int): _seek(float(bank[name_id].keys[i].t)))
    var erow:=HBoxContainer.new()
    side.add_child(erow)
    event_kind=OptionButton.new()
    for n in ["strike","charge","cast"]:event_kind.add_item(n)
    erow.add_child(event_kind)
    _button(erow,"Add event",_add_event)
    _button(erow,"Delete",_delete_event)
    event_list=ItemList.new()
    event_list.custom_minimum_size.y=48
    side.add_child(event_list)
    var save:=HBoxContainer.new()
    side.add_child(save)
    _button(save,"Save",_save)
    _button(save,"Load",func():bank=CLIPS.fighter_bank(fighter_index);_choose(name_id);dirty=false)
    _button(save,"Defaults",func():bank=CLIPS.defaults();_choose(name_id);dirty=true)
    _button(save,"Exit",func():_go("res://lab/main.tscn"))
    timeline=HSlider.new()
    timeline.position=Vector2(18,486)
    timeline.size=Vector2(922,24)
    timeline.step=1.0/60
    add_child(timeline)
    timeline.value_changed.connect(func(v:float):
        if not syncing: _seek(v))
    clock_label=Label.new()
    clock_label.position=Vector2(18,513)
    add_child(clock_label)
    status=Label.new()
    status.position=Vector2(245,513)
    status.text="Drag a hand or foot; Set key commits the edited pose."
    add_child(status)
    _choose(name_id)

func _choose(n: String) -> void:
    name_id=n
    playing=false
    _seek(0)
    _refresh_lists()

func _seek(v: float) -> void:
    playing=false
    time=clampf(v,0,float(bank[name_id].duration))
    pose=CLIPS.sample(bank[name_id],time,false)
    _sync()

func _sync() -> void:
    rig.evaluate(pose)
    preview.selected=selected
    preview.queue_redraw()
    syncing=true
    timeline.max_value=float(bank[name_id].duration)
    timeline.value=time
    duration.value=float(bank[name_id].duration)
    ease.button_pressed=bank[name_id].get("easing","smooth")=="smooth"
    loop.button_pressed=bank[name_id].loop
    angle.value=float(pose.angles.get(selected,0))
    root_x.value=float(pose.root[0])
    root_y.value=float(pose.root[1])
    joint_select.select(rig.ids[selected])
    clock_label.text="%.3f / %.2f s"%[time,bank[name_id].duration]
    syncing=false

func _edit() -> void:
    playing=false
    dirty=true
    status.text="Pose edited — Set key to commit at this time."
    _sync()

func _drag(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        dragging=e.pressed
        if dragging:
            var target: Vector2=e.position/3-preview.origin
            var nearest: float=7
            for j in rig.joints:
                var d: float=rig.point(j.id).distance_to(target)
                if d<nearest:
                    nearest=d
                    selected=j.id
            _sync()
    elif e is InputEventMouseMotion and dragging:
        pose=rig.solve_ik(pose,selected,e.position/3-preview.origin)
        _edit()

func _key() -> void:
    CLIPS.put_key(bank[name_id],time,pose)
    dirty=true
    _refresh_lists()
    status.text="Key stored at %.3f s"%time

func _delete_key() -> void:
    var rows: PackedInt32Array=keys.get_selected_items()
    if rows.size()>0 and bank[name_id].keys.size()>1:
        bank[name_id].keys.remove_at(rows[0])
        dirty=true
        _seek(time)
        _refresh_lists()

func _set_duration(v: float) -> void:
    if syncing:return
    var c: Dictionary=bank[name_id]
    var scale: float=v/float(c.duration)
    for k in c.keys:k.t=float(k.t)*scale
    for e in c.events:e.t=float(e.t)*scale
    c.duration=v
    dirty=true
    _seek(time*scale)
    _refresh_lists()

func _add_event() -> void:
    var c: Dictionary=bank[name_id]
    c.events.append({"t":time,"kind":event_kind.get_item_text(event_kind.selected),"anchor":selected})
    c.events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    dirty=true
    _refresh_lists()

func _delete_event() -> void:
    var rows: PackedInt32Array=event_list.get_selected_items()
    if rows.size()>0:
        bank[name_id].events.remove_at(rows[0])
        dirty=true
        _refresh_lists()

func _refresh_lists() -> void:
    keys.clear()
    event_list.clear()
    for k in bank[name_id].keys:keys.add_item("Key  %.3f s"%k.t)
    for e in bank[name_id].events:event_list.add_item("%.3f  %s @ %s"%[e.t,e.kind,e.anchor])

func _path() -> String:
    return CLIPS.SAVE_PATH if fighter_index==0 else CLIPS.SECOND_PATH

func _switch_fighter(i: int) -> void:
    if dirty and not CLIPS.save_bank(bank,_path()):
        fighter_select.select(fighter_index)
        status.text="Save failed; cannot switch fighters."
        return
    fighter_index=i
    bank=CLIPS.fighter_bank(i)
    preview.tint=Color("#5aafdc") if i==0 else Color("#ce775f")
    dirty=false
    _choose(name_id)

func _save() -> void:
    if CLIPS.save_bank(bank,_path()):
        dirty=false
        status.text="Saved to "+ProjectSettings.globalize_path(_path())
    else:
        status.text="Save failed: invalid clip data."

func _go(path: String) -> void:
    if dirty and not CLIPS.save_bank(bank,_path()):
        status.text="Could not save. Fix clip data before leaving."
        return
    get_tree().change_scene_to_file(path)

func _play() -> void:
    playing=not playing
    if playing and time>=float(bank[name_id].duration):time=0

func _process(dt: float) -> void:
    if not playing:return
    time+=dt
    var d: float=bank[name_id].duration
    if time>=d:
        if bank[name_id].loop:time=fposmod(time,d)
        else:time=d;playing=false
    pose=CLIPS.sample(bank[name_id],minf(d,floor(time*rate.value+.00001)/rate.value),false)
    _sync()
