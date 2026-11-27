extends Node2D
const Asset=preload("asset.gd")
const Goals=preload("goals.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const ORIGIN=Vector2(445,334)
const VIEW=Rect2(190,78,510,286)
const UI=preload("res://lab/ui_ru.gd")
const ZOOM=5.
const START=30
var document:Dictionary
var player
var body=Body.new(2)
var raster
var last_image:Image
var sprite:Sprite2D
var timeline
var status:Label
var info:Label
var motion:ItemList
var target_list:ItemList
var channel_tree:Tree
var channel_mode:OptionButton
var view_zoom:float=ZOOM
var show_handles:bool=true
var play_rate:float=1.
var loop_play:bool=true
var play_button:Button
var frame_label:Label
var key_channels:OptionButton
var key_angle:SpinBox
var key_apply:Button
var key_info:Label
var saved_signature:String=""
var dirty_label:Label
var switch_dialog:ConfirmationDialog
var requested_id:String=""
var inspector:TabContainer
var joints:OptionButton
var goal_list:OptionButton
var strength:SpinBox
var priority:SpinBox
var width:SpinBox
var param:SpinBox
var param_choice:OptionButton
var param_key:="speed"
var pose_controls:HBoxContainer
var selected:=-1
var history:Array=[]
var redo_history:Array=[]
var undo_button:Button
var redo_button:Button
var onion_enabled:bool=false
var ghost_sprites:Array[Sprite2D]=[]
var ghost_cache:Dictionary={}
var ghost_raster
var curve_view:CheckButton
var new_dialog:ConfirmationDialog
var new_name:LineEdit
var new_duration:SpinBox
var clip_board:Dictionary={}
var clock:=0.
var playing:=false
var dragging:=false

var gesture:Dictionary
var gesture_phase:=0.
var gesture_clock:=""
var syncing:=false
var frame:=0
var ids:Array=Asset.IDS.duplicate()

func _ready():
    panel(Rect2(0,0,960,540),"#101822")
    panel(Rect2(0,0,960,45),"#1c2938")
    panel(Rect2(8,50,174,314),"#192431")
    panel(VIEW,"#263442")
    panel(Rect2(708,50,244,314),"#192431")
    panel(Rect2(8,371,944,143),"#192431")
    var title:=caption(self,"МАСТЕРСКАЯ ДВИЖЕНИЙ",Vector2(12,12),18)
    dirty_label=caption(self,"",Vector2(278,14),13)
    dirty_label.size=Vector2(130,22)
    var top:=HBoxContainer.new()
    top.position=Vector2(414,7)
    add_child(top)
    button(top,"+ Действие",ask_new_action,"Создать новое ключевое действие Astra")
    button(top,"Копия",duplicate_motion,"Создать независимую копию JSON")
    button(top,"Сохранить",save_file,"Ctrl+S")
    button(top,"Загрузить",func():request_open(document.id),"Вернуться к сохранённому документу")
    undo_button=button(top,"↶",undo,"Отмена · Ctrl+Z")
    redo_button=button(top,"↷",redo,"Повтор · Ctrl+Shift+Z")
    button(top,"Меню",request_exit,"Esc")

    caption(self,"ДВИЖЕНИЯ",Vector2(16,55),12)
    motion=ItemList.new()
    motion.position=Vector2(14,76)
    motion.size=Vector2(162,97)
    motion.add_theme_font_size_override("font_size",13)
    add_child(motion)
    var directory:=DirAccess.open(Asset.FOLDER)
    if directory:
        for file in directory.get_files():
            var id:String=file.get_basename()
            if file.ends_with(".json") and id.is_valid_identifier() and not ids.has(id):ids.append(id)
    for id in ids:
        var path:String=Asset.FOLDER+id+".json"
        var entry:=Asset.read(path if FileAccess.file_exists(path) else Asset.DIR+id+".json")
        motion.add_item(str(entry.get("name",id)))
    motion.item_selected.connect(func(i):request_open(ids[i]))
    channel_mode=OptionButton.new()
    channel_mode.position=Vector2(14,175)
    channel_mode.size=Vector2(162,24)
    channel_mode.add_theme_font_size_override("font_size",12)
    channel_mode.add_item("Точки / IK")
    channel_mode.add_item("Каналы позы")
    add_child(channel_mode)
    channel_mode.item_selected.connect(func(i:int):target_list.visible=i==0;channel_tree.visible=i==1)
    target_list=ItemList.new()
    target_list.position=Vector2(14,201)
    target_list.size=Vector2(162,156)
    target_list.add_theme_font_size_override("font_size",12)
    add_child(target_list)
    for id in Asset.JOINTS:target_list.add_item(joint_name(id))
    target_list.item_selected.connect(func(i:int):
        joints.select(i)
        inspector.current_tab=1
        show_pose())
    target_list.select(0)
    channel_tree=Tree.new()
    channel_tree.position=target_list.position
    channel_tree.size=target_list.size
    channel_tree.hide_root=true
    channel_tree.add_theme_font_size_override("font_size",12)
    channel_tree.hide()
    add_child(channel_tree)
    channel_tree.item_selected.connect(select_channel_tree)

    var clip:=Control.new()
    clip.position=VIEW.position
    clip.size=VIEW.size
    clip.clip_contents=true
    clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    clip.z_index=-1
    add_child(clip)
    for color in [Color(.35,.75,1.,.33),Color(1.,.58,.28,.33)]:
        var ghost:=Sprite2D.new()
        ghost.centered=false
        ghost.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        ghost.modulate=color
        ghost.hide()
        clip.add_child(ghost)
        ghost_sprites.append(ghost)
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    clip.add_child(sprite)
    position_sprite()
    if ClassDB.class_exists("PixelFXBodyRaster"):
        raster=ClassDB.instantiate("PixelFXBodyRaster")
        ghost_raster=ClassDB.instantiate("PixelFXBodyRaster")
    var view_tools:=HBoxContainer.new()
    view_tools.position=Vector2(191,49)
    add_child(view_tools)
    caption(view_tools,"ВИД СБОКУ",Vector2.ZERO,12)
    var handles:=CheckButton.new()
    handles.text="Точки"
    handles.button_pressed=true
    view_tools.add_child(handles)
    handles.toggled.connect(func(v:bool):show_handles=v;queue_redraw())
    button(view_tools,"−",func():set_zoom(view_zoom-.5),"Уменьшить модель")
    button(view_tools,"+",func():set_zoom(view_zoom+.5),"Увеличить модель")
    button(view_tools,"1:1",func():set_zoom(ZOOM),"Сброс масштаба")
    button(view_tools,"К акценту",seek_accent,"К контакту / фазе полёта")
    var onion:=CheckButton.new()
    onion.text="Соседние"
    onion.tooltip_text="Синий: 4 кадра назад; оранжевый: 4 кадра вперёд. Только просмотр."
    view_tools.add_child(onion)
    onion.toggled.connect(func(v:bool):onion_enabled=v;update_ghosts())
    var help:=caption(self,"ЛКМ — потяни точку · колесо — масштаб",Vector2(202,346),12)
    help.mouse_filter=Control.MOUSE_FILTER_IGNORE

    inspector=TabContainer.new()
    inspector.position=Vector2(714,54)
    inspector.size=Vector2(232,305)
    inspector.add_theme_font_size_override("font_size",12)
    add_child(inspector)
    var movement:=tab("Движение")
    caption(movement,"Параметры документа",Vector2.ZERO,13)
    param_choice=OptionButton.new()
    param_choice.fit_to_longest_item=false
    movement.add_child(param_choice)
    param_choice.item_selected.connect(choose_param)
    param=SpinBox.new()
    param.step=.01
    movement.add_child(param)
    param.value_changed.connect(change_param)
    var note:=caption(movement,"Параметры меняют документ, а не частоту симуляции (60 Гц).",Vector2.ZERO,12)
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var goals:=tab("Цели")
    caption(goals,"Точка / сохранённая цель",Vector2.ZERO,12)
    joints=OptionButton.new()
    joints.fit_to_longest_item=false
    for id in Asset.JOINTS:joints.add_item(joint_name(id))
    goals.add_child(joints)
    joints.item_selected.connect(func(i:int):target_list.select(i);show_pose())
    goal_list=OptionButton.new()
    goal_list.fit_to_longest_item=false
    goals.add_child(goal_list)
    goal_list.item_selected.connect(func(i):select_goal(i-1);show_pose())
    strength=field(goals,"Вес",0,1,.05,1.)
    priority=field(goals,"Приоритет",0,9,1,1)
    width=field(goals,"Окно фазы",.01,1,.01,.20)
    for control in [strength,priority,width]:control.value_changed.connect(update_goal)
    var row:=HBoxContainer.new()
    goals.add_child(row)
    button(row,"Копия",copy_goal)
    button(row,"Вставить",paste_goal)
    button(row,"⇄",mirror_goal,"Создать цель парной конечности")
    button(goals,"Удалить цель",erase_goal)
    var keys_tab:=tab("Ключ")
    key_info=caption(keys_tab,"",Vector2.ZERO,12)
    key_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    key_channels=OptionButton.new()
    key_channels.fit_to_longest_item=false
    keys_tab.add_child(key_channels)
    key_channels.item_selected.connect(func(_i:int):sync_key();sync_curve())
    key_angle=field(keys_tab,"Угол, °",-360,360,.001,0.)
    key_apply=button(keys_tab,"Применить угол",apply_key_angle,"Изменить выбранный канал существующего ключа")
    pose_controls=HBoxContainer.new()
    keys_tab.add_child(pose_controls)
    button(pose_controls,"+ Ключ",key_pose)
    button(pose_controls,"− Ключ",delete_key)
    button(keys_tab,"± Контакт",toggle_contact,"Маркер удара выбранной кисти или стопы")

    var controls:=HBoxContainer.new()
    controls.position=Vector2(15,375)
    add_child(controls)
    play_button=button(controls,"▶ Пуск",toggle_play,"Space")
    button(controls,"|◀",func():seek(0),"Начало просмотра")
    button(controls,"−1",func():seek(maxi(0,frame-1)))
    button(controls,"+1",func():seek(mini(end_frame(),frame+1)))
    button(controls,"+ Ключ",key_pose,"Записать текущую позу действия")
    button(controls,"± Контакт",toggle_contact,"Добавить / удалить контакт выбранной кисти или стопы")
    var speed:=OptionButton.new()
    for label in ["×0.25","×0.5","×1"]:speed.add_item(label)
    speed.select(2)
    controls.add_child(speed)
    speed.item_selected.connect(func(i:int):play_rate=[.25,.5,1.][i])
    var loop:=CheckButton.new()
    loop.text="Цикл"
    loop.button_pressed=true
    controls.add_child(loop)
    loop.toggled.connect(func(v:bool):loop_play=v)
    curve_view=CheckButton.new()
    curve_view.text="График"
    curve_view.tooltip_text="Углы исходных ключей. Потяни точку вверх/вниз для правки угла; время меняется на дорожке Позы."
    controls.add_child(curve_view)
    curve_view.toggled.connect(func(v:bool):timeline.curve_mode=v;timeline.queue_redraw())
    frame_label=caption(self,"",Vector2(745,382),12)
    timeline=preload("res://lab/authoring/dopesheet.gd").new()
    timeline.position=Vector2(15,409)
    timeline.size=Vector2(930,99)
    timeline.step=1
    timeline.marker_moved.connect(move_marker)
    timeline.marker_selected.connect(func(lane:int,_i:int):
        if lane==0:inspector.current_tab=2
        else:inspector.current_tab=1)
    timeline.goal_selected.connect(func(i:int):select_goal(i);inspector.current_tab=1;show_pose())
    timeline.curve_edited.connect(edit_curve_key)
    add_child(timeline)
    timeline.value_changed.connect(func(v):if not syncing:seek(roundi(v)))
    status=caption(self,"",Vector2(14,517),12)
    status.size=Vector2(610,20)
    status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    info=caption(self,"",Vector2(630,517),12)
    info.size=Vector2(317,20)
    info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    switch_dialog=ConfirmationDialog.new()
    switch_dialog.title="Несохранённые изменения"
    switch_dialog.dialog_text="Отменить несохранённые правки и открыть выбранное движение?"
    add_child(switch_dialog)
    switch_dialog.confirmed.connect(func():
        if requested_id=="":get_tree().change_scene_to_file("res://lab/main.tscn")
        else:open_motion(requested_id))
    switch_dialog.canceled.connect(func():motion.select(ids.find(document.id)))
    new_dialog=ConfirmationDialog.new()
    new_dialog.title="Новое действие Astra"
    new_dialog.ok_button_text="Создать"
    var new_fields:=VBoxContainer.new()
    new_dialog.add_child(new_fields)
    caption(new_fields,"Имя действия",Vector2.ZERO,14)
    new_name=LineEdit.new()
    new_name.text="Новое действие"
    new_fields.add_child(new_name)
    new_duration=field(new_fields,"Длительность, с",.1,5.,.05,.5)
    caption(new_fields,"Начальная поза: текущая. Опора остаётся под Astra.",Vector2.ZERO,12)
    new_dialog.confirmed.connect(func():create_action(new_name.text,new_duration.value))
    add_child(new_dialog)
    open_motion(ids[0])

func panel(rect:Rect2,color:String)->void:
    var p:=ColorRect.new()
    p.position=rect.position
    p.size=rect.size
    p.color=Color(color)
    p.mouse_filter=Control.MOUSE_FILTER_IGNORE
    p.z_index=-2
    add_child(p)

func caption(parent:Node,value:String,pos:Vector2,font_size:int)->Label:
    var l:=Label.new()
    l.text=value
    l.position=pos
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",Color("#d9e5ef"))
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l

func tab(title:String)->VBoxContainer:
    var scroll:=ScrollContainer.new()
    scroll.name=title
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    inspector.add_child(scroll)
    var content:=VBoxContainer.new()
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",5)
    var theme:=Theme.new()
    theme.default_font_size=12
    content.theme=theme
    scroll.add_child(content)
    return content

func joint_name(id:String)->String:
    return UI.label(id)

func position_sprite()->void:
    sprite.position=ORIGIN-VIEW.position-Vector2(240,219)*view_zoom/3.
    sprite.scale=Vector2.ONE*view_zoom/3.
    for ghost in ghost_sprites:
        ghost.position=sprite.position
        ghost.scale=sprite.scale

func set_zoom(value:float)->void:
    view_zoom=clampf(value,3.,6.)
    position_sprite()
    queue_redraw()

func request_exit()->void:
    if JSON.stringify(document)!=saved_signature:
        requested_id=""
        switch_dialog.dialog_text="Выйти в меню без сохранения правок?"
        switch_dialog.popup_centered(Vector2i(400,140))
    else:get_tree().change_scene_to_file("res://lab/main.tscn")

func request_open(id:String)->void:
    if not document.is_empty() and JSON.stringify(document)!=saved_signature:
        requested_id=id
        switch_dialog.dialog_text="Отменить несохранённые правки и открыть выбранное движение?"
        switch_dialog.popup_centered(Vector2i(400,140))
        return
    open_motion(id)

func toggle_play()->void:
    playing=not playing
    clock=0.
    update_play_button()
    update_ghosts()

func update_play_button()->void:
    play_button.text="Ⅱ Пауза" if playing else "▶ Пуск"

func key_at_frame()->int:
    if document.kind!="action":return -1
    var index:int=-1
    var best:float=.50001
    for i in document.keys.size():
        var d:float=absf(document.keys[i].t*60.-(frame-START))
        if d<best:
            best=d
            index=i
    return index

func sync_key()->void:
    var i:int=key_at_frame()
    key_apply.disabled=i<0 or key_channels.item_count==0
    key_angle.editable=not key_apply.disabled
    key_info.text="Выбери ромб ключа. Углы редактируют исходную позу, не результат IK." if i<0 else "Ключ %d · кадр %d"%[i+1,frame-START]
    if not key_apply.disabled:
        var channel:String=key_channels.get_item_metadata(key_channels.selected)
        key_angle.set_value_no_signal(float(document.keys[i].angles[channel]))

func refresh_channel_tree()->void:
    channel_tree.clear()
    var root_item:TreeItem=channel_tree.create_item()
    for group in ["Корпус","Ближняя сторона","Дальняя сторона"]:
        var group_item:TreeItem=channel_tree.create_item(root_item)
        group_item.set_text(0,group)
        group_item.set_selectable(0,false)
        for i in key_channels.item_count:
            var id:String=key_channels.get_item_metadata(i)
            var category:String="Ближняя сторона" if id.ends_with("_near") else ("Дальняя сторона" if id.ends_with("_far") else "Корпус")
            if category!=group:continue
            var item:TreeItem=channel_tree.create_item(group_item)
            item.set_text(0,UI.label(id))
            item.set_metadata(0,id)
        if group_item.get_child_count()==0:group_item.set_text(0,group+" — нет ключей")

func select_channel_tree()->void:
    var item:TreeItem=channel_tree.get_selected()
    if item==null:return
    var id:String=str(item.get_metadata(0))
    for i in key_channels.item_count:
        if key_channels.get_item_metadata(i)==id:
            key_channels.select(i)
            inspector.current_tab=2
            sync_key()
            sync_curve()
            return

func edit_curve_key(index:int,value:float)->void:
    if document.kind!="action" or index<0 or index>=document.keys.size() or key_channels.selected<0:return
    var channel:String=key_channels.get_item_metadata(key_channels.selected)
    var next:float=clampf(value,-360.,360.)
    if is_equal_approx(float(document.keys[index].angles[channel]),next):return
    remember()
    document.keys[index].angles[channel]=next
    playing=false
    refresh(START+roundi(float(document.keys[index].t)*60.))

func sync_curve()->void:
    if timeline==null:return
    timeline.curve_keys=[]
    timeline.curve_label=""
    if document.kind=="action" and key_channels.item_count>0:
        var channel:String=key_channels.get_item_metadata(key_channels.selected)
        timeline.curve_label=UI.label(channel)
        for k in document.keys:
            timeline.curve_keys.append(Vector2(START+float(k.t)*60.,float(k.angles[channel])))
    timeline.queue_redraw()

func ask_new_action()->void:
    if JSON.stringify(document)!=saved_signature:
        info.text="Сначала сохрани или отмени текущие правки."
        return
    new_dialog.popup_centered(Vector2i(420,165))

func create_action(label:String,duration:float)->void:
    if player==null or label.strip_edges().is_empty():return
    var angles:Dictionary={}
    for channel in Asset.CHANNELS+["hips","pelvis_turn"]:
        angles[channel]=float(player.final_pose.angles.get(channel,0.))
    var index:int=1
    while ids.has("action_%d"%index) or FileAccess.file_exists(Asset.FOLDER+"action_%d.json"%index):index+=1
    var id:String="action_%d"%index
    var d:Dictionary={"version":1,"id":id,"name":label.strip_edges(),"kind":"action","duration":duration,"keys":[{"t":0.,"angles":angles.duplicate(true)},{"t":duration,"angles":angles.duplicate(true)}],"events":[],"goals":[]}
    var err:=Asset.persist(d)
    if err!=OK:
        info.text=error_string(err)
        return
    ids.append(id)
    motion.add_item(d.name)
    open_motion(id)
    seek(START)
    inspector.current_tab=2
    info.text="Создано. Добавь ключи и измени углы."

func remember()->void:
    history.append(document.duplicate(true))
    redo_history.clear()
    if history.size()>100:history.pop_front()

func update_ghosts()->void:
    for ghost in ghost_sprites:ghost.hide()
    if not onion_enabled or playing or player==null or ghost_raster==null:return
    for i in 2:
        var t:int=clampi(frame+[-4,4][i],0,end_frame())
        if t==frame:continue
        if not ghost_cache.has(t):
            var probe=Asset.player(document,60)
            for f in range(t+1):probe.step(command(f))
            var parts:Array=body.make(probe.rig.points,probe.final_pose.angles,probe.rig.rotations.head)
            Depth.apply(parts,probe.style)
            var result:Dictionary=ghost_raster.render(Studio.CFG,parts)
            if not result.get("ok",false):continue
            var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            if ghost_cache.size()>=12:ghost_cache.clear()
            ghost_cache[t]=ImageTexture.create_from_image(im)
        ghost_sprites[i].texture=ghost_cache[t]
        ghost_sprites[i].show()

func apply_key_angle()->void:
    var i:int=key_at_frame()
    if i<0 or key_channels.item_count==0:return
    remember()
    var channel:String=key_channels.get_item_metadata(key_channels.selected)
    document.keys[i].angles[channel]=key_angle.value
    refresh(frame)

func delete_key()->void:
    var i:int=key_at_frame()
    if i<=0 or i>=document.keys.size()-1:return
    remember()
    document.keys.remove_at(i)
    refresh(frame)

func field(parent:Control,title:String,lo:float,hi:float,step:float,initial:float)->SpinBox:
    var row:=HBoxContainer.new()
    parent.add_child(row)
    var l:=Label.new()
    l.text=title
    l.custom_minimum_size.x=93
    row.add_child(l)
    var spin:=SpinBox.new()
    spin.min_value=lo
    spin.max_value=hi
    spin.step=step
    spin.value=initial
    spin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    spin.get_line_edit().custom_minimum_size.x=32
    row.add_child(spin)
    return spin

func button(row:Control,title:String,fn:Callable,hint:String="")->Button:
    var b:=Button.new()
    b.text=title
    b.tooltip_text=hint
    b.add_theme_font_size_override("font_size",12)
    row.add_child(b)
    b.pressed.connect(fn)
    return b

func open_motion(id:String):
    var path:=Asset.FOLDER+id+".json"
    var d:=Asset.read(path if FileAccess.file_exists(path) else Asset.DIR+id+".json")
    var error:=Asset.problem(d)
    if error=="" and d.id!=id:error="Имя файла расходится с id"
    if error!="":
        info.text="Загрузка: "+error
        return
    document=d
    saved_signature=JSON.stringify(d)
    motion.select(ids.find(id))
    selected=-1
    history.clear()
    redo_history.clear()
    playing=false
    refresh(0)
    info.text="Крест — цель, круг — результат."

func end_frame()->int:
    return 220 if document.kind=="gait" else START+ceili(document.duration*60.)+22

func command(t:int)->Dictionary:
    if document.kind=="gait":return {"speed":1. if t<24 else (document.speed if t<132 else 0.)}
    return {"speed":0.,"action":document.id if t==START else ""}

func seek(value:int):
    playing=false
    update_play_button()
    simulate(value)

func simulate(value:int):
    if not player or value<=frame:
        player=Asset.player(document,60)
        frame=-1
    while frame<value:
        frame+=1
        player.step(command(frame))
    syncing=true
    timeline.value=frame
    syncing=false
    show_pose()

func refresh(value:int):
    ghost_cache.clear()
    player=null
    syncing=true
    param_choice.clear()
    if document.kind=="gait":
        for label in ["Скорость бега","Размах рук, °","Ширина полёта"]:param_choice.add_item(label)
        var keys:=["speed","arm_sweep","flight_width"]
        if not param_key in keys:param_key="speed"
        var i:=keys.find(param_key)
        param_choice.select(i)
        param.min_value=[1.,70.,2.][i]
        param.max_value=[1.85,115.,7.][i]
        param.value=document.get(param_key,[1.85,94.,5.][i])
    else:
        param_choice.add_item("Длительность, с")
        param.min_value=.05
        param.max_value=5.
        param.value=document.duration
    pose_controls.visible=document.kind=="action"
    goal_list.clear()
    goal_list.add_item("+ Новая цель")
    for g in document.goals:goal_list.add_item("%s · %.0f%%"%[joint_name(g.joint),g.center*100.])
    timeline.max_value=end_frame()
    timeline.clip={"keys":[],"events":[],"goals":[],"gait":document.kind=="gait","start":START}
    var previous_channel:String=""
    if key_channels.item_count>0:previous_channel=key_channels.get_item_metadata(key_channels.selected)
    key_channels.clear()
    if document.kind=="action":
        for channel in document.keys[0].angles:
            key_channels.add_item(UI.label(channel))
            key_channels.set_item_metadata(key_channels.item_count-1,channel)
            if channel==previous_channel:key_channels.select(key_channels.item_count-1)
        if key_channels.selected<0:key_channels.select(0)
        for i in document.goals.size():
            var g:Dictionary=document.goals[i]
            timeline.clip.goals.append({"t":START+g.center*document.duration*60.,"radius":g.width*document.duration*60.,"index":i})
    if document.kind=="action":
        for k in document.keys:timeline.clip.keys.append({"t":START+k.t*60})
        for e in document.events:timeline.clip.events.append({"t":START+e.t*60,"kind":e.kind})
    refresh_channel_tree()
    select_goal(selected)
    syncing=false
    simulate(clampi(value,0,end_frame()))

func select_goal(i:int):
    selected=i
    goal_list.select(i+1)
    if i<0:return
    var was:=syncing
    syncing=true
    var g:Dictionary=document.goals[i]
    joints.select(Asset.JOINTS.find(g.joint))
    target_list.select(joints.selected)
    strength.value=g.weight
    priority.value=g.priority
    width.value=g.width
    syncing=was

func show_pose():
    var rendered:bool=false
    if raster:
        var p:Dictionary=player.final_pose
        var parts:Array=body.make(player.rig.points,p.angles,player.rig.rotations.head)
        Depth.apply(parts,player.style)
        for i in [0,2,3,8,9]:parts[i].material_id=1
        for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
        var result:Dictionary=raster.render(Studio.CFG,parts)
        if result.ok:
            var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            last_image=im
            rendered=true
            if sprite.texture:sprite.texture.update(im)
            else:sprite.texture=ImageTexture.create_from_image(im)
    var state:String="стойка" if player.stopped else ("полёт" if airborne() else "опора")
    if player.action!="":state=player.action
    status.text="%s   ·   тик %d   ·   %s"%[document.name,frame,state]
    if not rendered:
        status.text+="  |  НЕТ НАТИВНОГО ТЕЛА — нужен полный пакет"
        sprite.hide()
    else:sprite.show()
    var joint:String=Asset.JOINTS[joints.selected]
    if player.goal_report.has(joint):
        var r:Dictionary=player.goal_report[joint]
        status.text+="   ·   %s   Δ %.2f"%[r.reason,at_joint(joint).distance_to(r.target)]
    frame_label.text=("%d / %d к."%[frame,end_frame()]) if document.kind=="gait" else ("%d к. · %.2f с"%[frame-START,float(frame-START)/60.])
    dirty_label.text="● Не сохранено" if JSON.stringify(document)!=saved_signature else "Сохранено"
    sync_key()
    sync_curve()
    update_play_button()
    undo_button.disabled=history.is_empty()
    redo_button.disabled=redo_history.is_empty()
    update_ghosts()
    queue_redraw()

func airborne()->bool:
    return not player.paths[0].stance and not player.paths[1].stance

func at_joint(joint:String)->Vector2:
    if joint.begins_with("foot"):return player.anchors[joint]-Vector2.RIGHT*player.gait.travel
    return player.rig.point(joint)

func _draw():
    if not player:return
    draw_line(Vector2(VIEW.position.x,ORIGIN.y),Vector2(VIEW.end.x,ORIGIN.y),Color("#73858e"))
    if not show_handles:return
    for j in Asset.JOINTS:
        var p:Vector2=ORIGIN+at_joint(j)*view_zoom
        if VIEW.has_point(p):
            draw_circle(p,4.,Color("#ffcf62") if j==Asset.JOINTS[joints.selected] else Color("#85c5c1"))
    for j in player.goal_report:
        var v:Vector2=ORIGIN+player.goal_report[j].target*view_zoom
        if not VIEW.has_point(v):continue
        draw_line(v-Vector2(6,0),v+Vector2(6,0),Color.CORAL,2)
        draw_line(v-Vector2(0,6),v+Vector2(0,6),Color.CORAL,2)
        var actual:Vector2=ORIGIN+at_joint(j)*view_zoom
        if VIEW.has_point(actual):draw_line(v,actual,Color.CORAL)

func move_marker(lane:int,index:int,value:float):
    if document.kind!="action":return
    var entries:Array=document.keys if lane==0 else document.events
    if lane==0 and index in [0,entries.size()-1]:return
    var t:=clampf((roundf(value)-START)/60.,0.,document.duration)
    if lane==0 and (t<=entries[index-1].t or t>=entries[index+1].t):return
    remember()
    entries[index].t=t
    refresh(START+roundi(t*60))

func seek_accent():
    if document.kind=="action":
        seek(START+roundi((document.events[0].t if document.events.size() else document.duration*.45)*60))
        return
    seek(65)
    while frame<130 and not airborne():simulate(frame+1)

func _unhandled_input(event):
    if event is InputEventKey and UI.editor_shortcut(self,event):
        match UI.physical_key(event):
            KEY_SPACE:toggle_play()
            KEY_ESCAPE:request_exit()
            KEY_Z:
                if event.ctrl_pressed:
                    if event.shift_pressed:redo()
                    else:undo()
            KEY_Y:
                if event.ctrl_pressed:redo()
            KEY_S:
                if event.ctrl_pressed:save_file()
    if event is InputEventMouseButton and event.pressed and VIEW.has_point(event.position):
        if event.button_index==MOUSE_BUTTON_WHEEL_UP:set_zoom(view_zoom+.5)
        elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:set_zoom(view_zoom-.5)
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if not event.pressed:
            dragging=false
        elif show_handles and VIEW.has_point(event.position):
            var preferred:String=Asset.JOINTS[joints.selected]
            if event.position.distance_to(ORIGIN+at_joint(preferred)*view_zoom)<=6.:
                begin_drag(preferred)
                return
            var best:=18.
            var id:=""
            for j in Asset.JOINTS:
                var distance:float=event.position.distance_to(ORIGIN+at_joint(j)*view_zoom)
                if distance<best:
                    best=distance
                    id=j
            if id!="":begin_drag(id)
    if event is InputEventMouseMotion and dragging:drag_to((event.position-ORIGIN)/view_zoom)

func begin_drag(joint:String):
    playing=false
    var phase_clock:="action"
    if document.kind=="gait":
        phase_clock="swing_"+joint.get_slice("_",1)
        if Goals.phase(player,phase_clock)<0.:phase_clock="cycle"
    var t:=Goals.phase(player,phase_clock)
    if phase_clock=="action" and t>=0.:t=float(player.age-1)/maxi(1,player.bank[player.action].frames.size()-1)
    if t<0. or t>1.:
        info.text="Выбери фазу самого действия."
        return
    gesture=document.duplicate(true)
    gesture_phase=t
    gesture_clock=phase_clock
    if selected>=0 and document.goals[selected].joint!=joint:selected=-1
    joints.select(Asset.JOINTS.find(joint))
    target_list.select(joints.selected)
    inspector.current_tab=1
    dragging=true

func drag_to(point:Vector2):
    if not dragging:return
    if not gesture.is_empty():
        history.append(gesture)
        redo_history.clear()
        if history.size()>100:history.pop_front()
        gesture={}
    var xy:=[clampf(point.x,-128,128),clampf(point.y,-128,128)]
    var data:={"joint":Asset.JOINTS[joints.selected],"xy":xy,"clock":gesture_clock,"center":gesture_phase,"width":width.value,"weight":strength.value,"priority":int(priority.value)}
    if selected<0:
        selected=document.goals.size()
        if selected>=64:
            selected=-1
            dragging=false
            return
        document.goals.append(data)
    else:document.goals[selected]=data
    refresh(frame)

func update_goal(_v:float):
    if syncing or selected<0:return
    remember()
    var g:Dictionary=document.goals[selected]
    g.weight=strength.value
    g.priority=int(priority.value)
    g.width=width.value
    refresh(frame)

func change_param(value:float):
    if syncing:return
    remember()
    if document.kind=="gait":document[param_key]=value
    else:
        var ratio:float=value/document.duration
        for k in document.keys:k.t*=ratio
        for e in document.events:e.t*=ratio
        document.duration=value
    refresh(frame)

func choose_param(i:int):
    if document.kind=="gait":
        param_key=["speed","arm_sweep","flight_width"][i]
        refresh(frame)

func key_pose():
    if player.action=="":return
    var t:=clampf((frame-START)/60.,0.,document.duration)
    var angles:Dictionary={}
    for id in document.keys[0].angles:angles[id]=player.final_pose.angles[id]
    remember()
    for k in document.keys:
        if absf(t-k.t)<.00001:
            k.angles=angles
            refresh(frame)
            return
    if document.keys.size()<256:
        document.keys.append({"t":t,"angles":angles})
        document.keys.sort_custom(func(a,b):return a.t<b.t)
    refresh(frame)

func toggle_contact():
    if player.action=="":return
    var id:String=Asset.JOINTS[joints.selected]
    if not (id.begins_with("hand") or id.begins_with("foot")):return
    var t:=clampf((frame-START)/60.,0.,document.duration)
    remember()
    for i in document.events.size():
        if roundi(document.events[i].t*60)==roundi(t*60) and document.events[i].anchor==id:
            document.events.remove_at(i)
            refresh(frame)
            return
    if document.events.size()<32:document.events.append({"t":t,"kind":"strike","anchor":id})
    refresh(frame)

func copy_goal():
    if selected>=0:clip_board=document.goals[selected].duplicate(true)

func paste_goal():
    if clip_board.is_empty() or document.goals.size()>=64:return
    remember()
    var g:=clip_board.duplicate(true)
    if document.kind=="action":g.clock="action"
    elif g.clock=="action":g.clock="cycle"
    document.goals.append(g)
    selected=document.goals.size()-1
    refresh(frame)

func mirror_goal():
    if selected<0 or document.goals.size()>=64:return
    var g:Dictionary=document.goals[selected].duplicate(true)
    var near:bool=g.joint.ends_with("_near")
    g.joint=g.joint.get_slice("_",0)+("_far" if near else "_near")
    if g.clock=="cycle":g.center=fposmod(g.center+.5,1.)
    if g.clock.begins_with("swing_"):g.clock="swing_"+g.joint.get_slice("_",1)
    remember()
    document.goals.append(g)
    selected=document.goals.size()-1
    refresh(frame)

func erase_goal():
    if selected<0:return
    remember()
    document.goals.remove_at(selected)
    selected=-1
    refresh(frame)

func undo():
    if history.is_empty():return
    redo_history.append(document.duplicate(true))
    document=history.pop_back()
    selected=-1
    refresh(frame)

func redo():
    if redo_history.is_empty():return
    history.append(document.duplicate(true))
    document=redo_history.pop_back()
    selected=-1
    refresh(frame)

func save_file():
    var err:=Asset.persist(document)
    if err==OK:saved_signature=JSON.stringify(document)
    info.text="Сохранено: "+document.id+".json" if err==OK else error_string(err)
    show_pose()

func duplicate_motion():
    var d:=document.duplicate(true)
    var index:=1
    while ids.has("motion_%d"%index):index+=1
    d.id="motion_%d"%index
    d.name=d.name+" · "+str(index)
    if Asset.persist(d)!=OK:return
    ids.append(d.id)
    motion.add_item(d.name)
    motion.select(ids.size()-1)
    open_motion(d.id)

func _process(delta:float):
    if not playing:return
    clock+=delta*play_rate
    var steps:=floori(clock*60.)
    if steps>0:
        clock-=steps/60.
        var next:int=frame+steps
        if loop_play:simulate(next%(end_frame()+1))
        else:
            simulate(mini(next,end_frame()))
            if next>=end_frame():playing=false;update_play_button()
