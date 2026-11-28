extends Node2D
const Asset=preload("asset.gd")
const AttackRecovery=preload("res://lab/attack_recovery.gd")
const AttackAdapt=preload("res://lab/attack_adaptation.gd")
const Punch=preload("res://lab/training_punch.gd")
const WalkMotion=preload("res://lab/walk_motion.gd")
const WalkPreview=preload("res://lab/walk_preview.gd")
const Goals=preload("goals.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const ORIGIN=Vector2(445,334)
const VIEW=Rect2(190,78,510,286)
const UI=preload("res://lab/ui_ru.gd")
const ZOOM=5.
const Clips=preload("res://addons/creature/clips.gd")
const VFX=preload("res://addons/pixelfx/composer/preset.gd")
const FXPreview=preload("res://addons/creature/vfx_preview.gd")
const FXSurface=preload("res://addons/pixelfx/native/surface.gd")
const QuickVFX=preload("res://lab/vfx_quick_dialog.gd")
const BONE_END={"hips":"chest","chest":"head","shoulder_near":"elbow_near","elbow_near":"hand_near","shoulder_far":"elbow_far","elbow_far":"hand_far","thigh_near":"knee_near","knee_near":"foot_near","thigh_far":"knee_far","knee_far":"foot_far"}
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
var delete_motion_button:Button
var delete_motion_dialog:ConfirmationDialog
var delete_motion_id:String=""
var target_list:ItemList
var channel_tree:Tree
var channel_mode:OptionButton
var pose_tool:OptionButton
var pose_hint:Label
var pose_rig=Body.make_rig()
var edit_pose:Dictionary={}
var rotate_channel:String=""
var rotate_pivot:=Vector2.ZERO
var rotate_last:float=0.
var rotate_delta:float=0.
var rotate_initial:float=0.
var rotate_active:bool=false
var rotate_changed:bool=false
var rotate_key:int=-1
var rotate_time:float=0.
var rotate_angles:Dictionary={}
var root_drag_active:bool=false
var root_drag_start:=Vector2.ZERO
var root_drag_initial:=Vector2.ZERO
var root_drag_delta:=Vector2.ZERO
var root_drag_time:=0.
var root_drag_key:int=-1
var root_drag_changed:bool=false
var reference_sprite:Sprite2D
var reference_file:FileDialog
var reference_scale:SpinBox
var reference_opacity:SpinBox
var reference_x:SpinBox
var reference_y:SpinBox
var reference_visible:CheckButton
var reference_name:Label
var fx_surface
var fx_preview=FXPreview.new()
var fx_visible:CheckButton
var event_list:ItemList
var event_kind:OptionButton
var event_anchor:OptionButton
var vfx_select:OptionButton
var vfx_choices:Array=[]
var selected_event:int=-1
var quick_dialog
var import_dialog:FileDialog
var fps_select:OptionButton
var easing_select:OptionButton
var attack_role_select:OptionButton
var landing_select:OptionButton
var loop_toggle:CheckButton
var root_x:SpinBox
var root_y:SpinBox
var preview_speed_select:OptionButton
var preview_speed:float=0.
var release_panel:VBoxContainer
var release_side:OptionButton
var release_fields:Array[SpinBox]=[]
var release_state:Label
var release_remove:Button
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
var ids:Array=Asset.WALK_IDS+Asset.TRAIN_IDS+Asset.IDS

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
    var choreography:=Button.new()
    choreography.text="Хореография"
    choreography.position=Vector2(267,6)
    add_child(choreography)
    choreography.pressed.connect(func():
        var window=get_node_or_null("Choreography")
        if not window:
            window=preload("choreography/panel.gd").new()
            window.name="Choreography"
            add_child(window)
        window.popup_centered())
    var top:=HBoxContainer.new()
    top.position=Vector2(400,7)
    add_child(top)
    button(top,"+ Действие",ask_new_action,"Создать новое ключевое действие Astra")
    button(top,"Копия",duplicate_motion,"Создать независимую копию JSON")
    button(top,"Сохранить",save_file,"Ctrl+S")
    button(top,"Открыть",func():request_open(document.id),"Вернуться к сохранённому документу")
    button(top,"Импорт U",func():import_dialog.popup_centered_ratio(.75),"Перенести клипы из старого редактора U в формат Astra")
    undo_button=button(top,"↶",undo,"Отмена · Ctrl+Z")
    redo_button=button(top,"↷",redo,"Повтор · Ctrl+Shift+Z")
    button(top,"Меню",request_exit,"Esc")

    caption(self,"ДВИЖЕНИЯ",Vector2(16,55),12)
    delete_motion_button=button(self,"Удалить",ask_delete_motion,"Удалить пользовательское движение")
    delete_motion_button.position=Vector2(101,50)
    delete_motion_button.size=Vector2(75,24)
    delete_motion_dialog=ConfirmationDialog.new()
    delete_motion_dialog.title="Удаление движения"
    delete_motion_dialog.ok_button_text="Удалить"
    delete_motion_dialog.confirmed.connect(func():delete_user_motion(delete_motion_id))
    add_child(delete_motion_dialog)
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
        var entry:=bound_document(id,path)
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
    reference_sprite=Sprite2D.new()
    reference_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    reference_sprite.hide()
    clip.add_child(reference_sprite)
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
    fx_surface=FXSurface.new()
    clip.add_child(fx_surface)
    fx_surface.configure(480,270)
    fx_preview.rig=Body.make_rig()
    fx_surface.hide()
    position_sprite()
    quick_dialog=QuickVFX.new()
    add_child(quick_dialog)
    quick_dialog.applied.connect(apply_quick_vfx)
    import_dialog=FileDialog.new()
    import_dialog.title="Импорт клипов старого редактора U"
    import_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
    import_dialog.access=FileDialog.ACCESS_FILESYSTEM
    import_dialog.filters=PackedStringArray(["*.json ; Банк анимаций U (JSON)"])
    import_dialog.file_selected.connect(import_legacy_file)
    add_child(import_dialog)
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
    pose_tool=OptionButton.new()
    pose_tool.position=Vector2(195,338)
    pose_tool.size=Vector2(130,24)
    pose_tool.add_theme_font_size_override("font_size",12)
    pose_tool.add_item("Цели / IK")
    pose_tool.add_item("Поза / FK")
    pose_tool.add_item("Исполнение")
    pose_tool.tooltip_text="IK: цели Astra. FK: исходные углы. Исполнение: результат без редактирования."
    add_child(pose_tool)
    pose_tool.item_selected.connect(set_pose_tool)
    pose_hint=caption(self,"",Vector2(333,345),12)
    pose_hint.size=Vector2(360,17)
    pose_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    pose_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE

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
    fps_select=OptionButton.new()
    for value in [24,30,60]:fps_select.add_item("%d кадров/с"%value)
    movement.add_child(fps_select)
    fps_select.item_selected.connect(set_fps)
    easing_select=OptionButton.new()
    for label in ["Линейно","Плавно","Ускорение","Ступень"]:easing_select.add_item(label)
    movement.add_child(easing_select)
    easing_select.item_selected.connect(set_easing)
    attack_role_select=OptionButton.new()
    for label in ["Роль: автоматически","Роль: передняя","Роль: задняя","Роль: ближняя","Роль: дальняя","Роль: авторская"]:attack_role_select.add_item(label)
    movement.add_child(attack_role_select)
    attack_role_select.item_selected.connect(set_attack_role)
    landing_select=OptionButton.new()
    for label in ["Финиш: авторский","Финиш: шаг вперёд"]:landing_select.add_item(label)
    movement.add_child(landing_select)
    landing_select.item_selected.connect(set_landing_policy)
    loop_toggle=CheckButton.new()
    loop_toggle.text="Циклическое движение"
    movement.add_child(loop_toggle)
    loop_toggle.toggled.connect(set_loop)
    var note:=caption(movement,"Сетка ключей: выбранный FPS. Симуляция Astra остаётся 60 Гц; FPS не меняет физику.",Vector2.ZERO,12)
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    release_panel=VBoxContainer.new()
    movement.add_child(release_panel)
    caption(release_panel,"ОПОРА / АВТОРСКАЯ НОГА",Vector2.ZERO,12)
    release_side=OptionButton.new()
    release_side.add_item("Ближняя нога")
    release_side.add_item("Дальняя нога")
    release_panel.add_child(release_side)
    release_side.item_selected.connect(func(_i:int):sync_release())
    release_state=caption(release_panel,"",Vector2.ZERO,12)
    release_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for pair in [["Начало, %",0.],["Полная, %",18.],["Возврат, %",75.],["Опора, %",100.]]:
        release_fields.append(field(release_panel,pair[0],0.,100.,1.,pair[1]))
    button(release_panel,"Применить фазы",apply_release,"Добавить каналы ноги и задать окно авторского контроля")
    release_remove=button(release_panel,"Вернуть опору Astra",remove_release)
    var leg_note:=caption(release_panel,"Опора вне окна процедурная. Физика Box2D не используется.",Vector2.ZERO,12)
    leg_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
    key_channels.item_selected.connect(func(_i:int):sync_key();sync_curve();queue_redraw())
    key_angle=field(keys_tab,"Угол, °",-360,360,.001,0.)
    key_apply=button(keys_tab,"Применить угол",apply_key_angle,"Изменить выбранный канал существующего ключа")
    pose_controls=HBoxContainer.new()
    keys_tab.add_child(pose_controls)
    button(pose_controls,"+ Ключ",key_pose)
    button(pose_controls,"− Ключ",delete_key)
    button(keys_tab,"± Контакт",toggle_contact,"Маркер удара выбранной кисти или стопы")
    var mirror_row:=HBoxContainer.new()
    keys_tab.add_child(mirror_row)
    button(mirror_row,"Зеркало движения",mirror_action,"Отразить ключи, корень, цели, события и фазы ног")
    root_x=field(keys_tab,"Смещение X",-40.,40.,.1,0.)
    root_y=field(keys_tab,"Смещение Y",-40.,40.,.1,0.)
    root_x.value_changed.connect(func(_v:float):apply_key_root())
    root_y.value_changed.connect(func(_v:float):apply_key_root())
    var refs:=tab("Реф.")
    reference_name=caption(refs,"Нет изображения",Vector2.ZERO,12)
    reference_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    var ref_row:=HBoxContainer.new()
    refs.add_child(ref_row)
    button(ref_row,"Открыть…",func():reference_file.popup_centered_ratio(.75))
    button(ref_row,"Удалить",clear_reference)
    reference_visible=CheckButton.new()
    reference_visible.text="Показывать"
    reference_visible.button_pressed=true
    refs.add_child(reference_visible)
    reference_visible.toggled.connect(func(_v:bool):update_reference())
    reference_opacity=field(refs,"Прозрачн.",0.,1.,.05,.35)
    reference_scale=field(refs,"Масштаб",.1,3.,.05,1.)
    reference_x=field(refs,"Сдвиг X",-500.,500.,1.,0.)
    reference_y=field(refs,"Сдвиг Y",-300.,300.,1.,0.)
    for spin in [reference_opacity,reference_scale,reference_x,reference_y]:
        spin.value_changed.connect(func(_v:float):update_reference())
    button(refs,"Сброс вида",reset_reference_view)
    var ref_note:=caption(refs,"Локальный PNG/JPG/WebP. Не входит в JSON движения.",Vector2.ZERO,12)
    ref_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    reference_file=FileDialog.new()
    reference_file.title="Выбрать референс"
    reference_file.file_mode=FileDialog.FILE_MODE_OPEN_FILE
    reference_file.access=FileDialog.ACCESS_FILESYSTEM
    reference_file.filters=PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Изображения"])
    reference_file.file_selected.connect(load_reference)
    add_child(reference_file)
    var events_tab:=tab("События")
    caption(events_tab,"Маркеры действия",Vector2.ZERO,12)
    event_kind=OptionButton.new()
    for label in ["Удар","Заряд","Каст","VFX"]:event_kind.add_item(label)
    events_tab.add_child(event_kind)
    event_anchor=OptionButton.new()
    for id in Asset.EVENT_ANCHORS:event_anchor.add_item(joint_name(id))
    event_anchor.select(Asset.EVENT_ANCHORS.find("hand_near"))
    events_tab.add_child(event_anchor)
    event_list=ItemList.new()
    event_list.custom_minimum_size.y=84
    events_tab.add_child(event_list)
    event_list.item_selected.connect(select_event)
    var event_actions:=HBoxContainer.new()
    events_tab.add_child(event_actions)
    button(event_actions,"+ Маркер",add_event)
    button(event_actions,"Удалить",delete_event)
    vfx_select=OptionButton.new()
    vfx_select.fit_to_longest_item=false
    vfx_select.clip_text=true
    vfx_select.tooltip_text="Пресет для VFX-маркера"
    events_tab.add_child(vfx_select)
    var vfx_actions:=HBoxContainer.new()
    events_tab.add_child(vfx_actions)
    button(vfx_actions,"+ VFX",add_vfx_event)
    button(vfx_actions,"Заменить",replace_vfx_event)
    button(events_tab,"Быстрая настройка VFX",open_quick_vfx)
    fx_visible=CheckButton.new()
    fx_visible.text="Показывать VFX в просмотре"
    fx_visible.button_pressed=true
    events_tab.add_child(fx_visible)
    fx_visible.toggled.connect(func(_v:bool):render_vfx())
    load_vfx_library()
    var event_note:=caption(events_tab,"Strike — игровой контакт. Charge/Cast/VFX — визуальные события; сами по себе не наносят урон.",Vector2.ZERO,11)
    event_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

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
    preview_speed_select=OptionButton.new()
    for label in ["Стойка","Ходьба","Бег"]:preview_speed_select.add_item(label)
    preview_speed_select.select(0)
    controls.add_child(preview_speed_select)
    preview_speed_select.item_selected.connect(set_preview_speed)
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
    timeline.marker_selected.connect(func(lane:int,i:int):
        if lane==0:inspector.current_tab=2
        elif not is_bound():
            inspector.current_tab=4
            event_list.select(i)
            select_event(i))
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
    if fx_surface:
        fx_surface.position=sprite.position
        fx_surface.scale=sprite.scale
    for ghost in ghost_sprites:
        ghost.position=sprite.position
        ghost.scale=sprite.scale

func set_zoom(value:float)->void:
    view_zoom=clampf(value,3.,6.)
    position_sprite()
    queue_redraw()

func import_legacy_file(path:String)->void:
    if JSON.stringify(document)!=saved_signature:
        info.text="Сначала сохрани или отмени текущие правки."
        return
    var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        info.text="Файл U не является JSON-банком."
        return
    var imported:Array=[]
    if parsed.has("payload") and parsed.payload is Dictionary and parsed.payload.has("clip"):
        var payload:Dictionary=parsed.payload
        var slot:String=str(payload.get("slot",path.get_file().get_basename()))
        var label:String=str(parsed.get("name",slot))
        imported.append(Asset.legacy_clip_to_action(payload.clip,"u_"+slot.to_snake_case(),label,30))
    elif Asset.legacy_clip_valid(parsed):
        var base_id:String="u_"+path.get_file().get_basename().to_snake_case()
        imported.append(Asset.legacy_clip_to_action(parsed,base_id,path.get_file().get_basename(),30))
    else:imported=Asset.import_legacy_bank(parsed,"u",30)
    var count:int=0
    for source in imported:
        if source.is_empty():continue
        var d:Dictionary=source.duplicate(true)
        var stem:String=d.id
        var suffix:int=1
        while ids.has(d.id) or FileAccess.file_exists(Asset.FOLDER+d.id+".json"):
            d.id=stem+"_"+str(suffix)
            suffix+=1
        if Asset.persist(d)!=OK:continue
        ids.append(d.id)
        motion.add_item(d.name)
        count+=1
    if count>0:
        motion.select(ids.size()-1)
        open_motion(ids[-1])
        info.text="Импортировано клипов U: %d. Исходный банк не изменён."%count
    else:info.text="В файле не найдено поддерживаемых клипов U."

func set_fps(index:int)->void:
    if syncing or document.kind!="action":return
    remember()
    document.fps=[24,30,60][index]
    refresh(frame)

func set_attack_role(index:int)->void:
    if syncing or not document.get("training_attack",false):return
    remember()
    document.limb_role=AttackAdapt.ROLES[index]
    refresh(frame)

func set_landing_policy(index:int)->void:
    if syncing or not document.get("training_attack",false):return
    remember()
    document.landing_policy=["authored","forward_land"][index]
    refresh(frame)

func set_easing(index:int)->void:
    if syncing or document.kind!="action":return
    remember()
    document.easing=Asset.EASING[index]
    for key in document.keys:key.erase("easing")
    refresh(frame)

func set_loop(value:bool)->void:
    if syncing or document.kind!="action" or is_bound():return
    remember()
    document.loop=value
    var error:String=Asset.problem(document)
    if error!="":
        document.loop=not value
        loop_toggle.set_pressed_no_signal(not value)
        history.pop_back()
        info.text=error
        return
    refresh(frame)

func set_preview_speed(index:int)->void:
    preview_speed=[0.,1.,1.85][index]
    seek(0)

func apply_key_root()->void:
    if syncing or document.kind!="action":return
    var index:int=key_at_frame()
    if index<0:return
    var next:Array=[root_x.value,root_y.value]
    if document.keys[index].get("root",[0.,0.])==next:return
    remember()
    document.keys[index].root=next
    refresh(frame)

func mirror_id(id:String)->String:
    if id.ends_with("_near"):return id.trim_suffix("_near")+"_far"
    if id.ends_with("_far"):return id.trim_suffix("_far")+"_near"
    return id

func mirror_action()->void:
    if document.kind!="action" or is_bound():return
    remember()
    for k in document.keys:
        var mirrored:Dictionary={}
        for id in k.angles:mirrored[mirror_id(str(id))]=-float(k.angles[id])
        k.angles=mirrored
        var root:Array=k.get("root",[0.,0.])
        k.root=[-float(root[0]),float(root[1])]
    for g in document.goals:
        g.joint=mirror_id(str(g.joint))
        g.xy[0]=-float(g.xy[0])
    for event in document.events:event.anchor=mirror_id(str(event.anchor))
    var release:Dictionary=document.get("release",{})
    var mirrored_release:Dictionary={}
    if release.has("near"):mirrored_release.far=release.near.duplicate()
    if release.has("far"):mirrored_release.near=release.far.duplicate()
    document.release=mirrored_release
    refresh(frame)
    info.text="Движение зеркально отражено."

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
    if document.get("walk_role","")=="walk_idle":
        playing=false
        seek(START)
        return
    if rotate_active:cancel_rotation()
    if root_drag_active:finish_root_drag()
    if pose_tool.selected==1:pose_tool.select(2)
    playing=not playing
    clock=0.
    show_pose()

func update_play_button()->void:
    play_button.text="Ⅱ Пауза" if playing else "▶ Пуск"

func key_at_frame()->int:
    if document.kind!="action":return -1
    if document.get("walk_role","")=="walk_idle":return 0
    var index:int=-1
    var best:float=.50001
    for i in document.keys.size():
        var d:float=absf(document.keys[i].t*60.-(frame-START))
        if d<best:
            best=d
            index=i
    if document.has("walk_role") and document.walk_role!="walk_idle" and index==document.keys.size()-1:return 0
    return index

func sync_key()->void:
    var i:int=key_at_frame()
    key_apply.disabled=i<0 or key_channels.item_count==0
    key_angle.editable=not key_apply.disabled
    key_info.text="Статичная поза · кадр 0" if document.get("walk_role","")=="walk_idle" else ("Выбери ромб ключа. Углы редактируют исходную позу, не результат IK." if i<0 else "Ключ %d · кадр %d"%[i+1,frame-START])
    root_x.editable=i>=0
    root_y.editable=i>=0
    if not key_apply.disabled:
        var channel:String=key_channels.get_item_metadata(key_channels.selected)
        key_angle.set_value_no_signal(float(document.keys[i].angles[channel]))
        root_x.set_value_no_signal(float(document.keys[i].get("root",[0.,0.])[0]))
        root_y.set_value_no_signal(float(document.keys[i].get("root",[0.,0.])[1]))


func load_vfx_library()->void:
    vfx_choices.clear()
    vfx_select.clear()
    for i in 12:
        var preset:Dictionary=VFX.demo(i)
        vfx_choices.append(preset)
        vfx_select.add_item("Демо: "+str(preset.name))
    var directory:=DirAccess.open(VFX.FOLDER)
    if directory:
        for file in directory.get_files():
            if not file.ends_with(".json"):continue
            var preset:Dictionary=VFX.load_preset(VFX.FOLDER.path_join(file))
            if preset.is_empty():continue
            vfx_choices.append(preset)
            vfx_select.add_item("Свой: "+str(preset.name))
    if not vfx_choices.is_empty():vfx_select.select(0)

func sync_events()->void:
    if event_list==null:return
    event_list.clear()
    selected_event=-1
    for event in document.get("events",[]):
        var label:String=str(event.kind).to_upper()+" · %.3f · %s"%[event.t,joint_name(str(event.anchor))]
        if event.kind=="vfx":label=str(event.preset.name)+" · %.3f"%event.t
        event_list.add_item(label)
        if event.kind=="vfx":event_list.set_item_custom_fg_color(event_list.item_count-1,Color("#c5a1ff"))

func select_event(index:int)->void:
    if index<0 or index>=document.events.size():return
    selected_event=index
    var event:Dictionary=document.events[index]
    event_kind.select(["strike","charge","cast","vfx"].find(str(event.kind)))
    event_anchor.select(Asset.EVENT_ANCHORS.find(str(event.anchor)))
    timeline.selected_lane=1
    timeline.selected_index=index
    seek(START+roundi(float(event.t)*60.))
    inspector.current_tab=4
    timeline.queue_redraw()

func add_event()->void:
    if is_bound():return
    if document.kind!="action" or document.events.size()>=32:return
    if event_kind.selected==0 and document.get("loop",false):
        info.text="Циклическое действие не может содержать боевой контакт."
        return
    if event_kind.selected==0 and not Asset.EVENT_ANCHORS[event_anchor.selected].begins_with("hand_") and not Asset.EVENT_ANCHORS[event_anchor.selected].begins_with("foot_"):
        info.text="Strike должен быть привязан к кисти или стопе."
        return
    if event_kind.selected==3:
        add_vfx_event()
        return
    remember()
    var t:=clampf(float(frame-START)/60.,0.,document.duration)
    t=clampf(snappedf(t,1./float(document.get("fps",60))),0.,document.duration)
    var marker:Dictionary={"t":t,"kind":["strike","charge","cast","vfx"][event_kind.selected],"anchor":Asset.EVENT_ANCHORS[event_anchor.selected]}
    document.events.append(marker)
    document.events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    refresh(frame)
    info.text="Событие добавлено."

func add_vfx_event()->void:
    if is_bound():return
    if document.kind!="action" or document.events.size()>=32 or vfx_select.selected<0:return
    remember()
    var t:=clampf(float(frame-START)/60.,0.,document.duration)
    t=clampf(snappedf(t,1./float(document.get("fps",60))),0.,document.duration)
    var marker:Dictionary={"t":t,"kind":"vfx","anchor":Asset.EVENT_ANCHORS[event_anchor.selected],"preset":vfx_choices[vfx_select.selected].duplicate(true)}
    document.events.append(marker)
    document.events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    refresh(frame)
    info.text="VFX-маркер добавлен."

func delete_event()->void:
    if selected_event<0 or selected_event>=document.events.size():return
    remember()
    document.events.remove_at(selected_event)
    refresh(frame)
    info.text="Событие удалено."

func replace_vfx_event()->void:
    if selected_event<0 or selected_event>=document.events.size() or vfx_select.selected<0:return
    if document.events[selected_event].kind!="vfx":return
    remember()
    document.events[selected_event].preset=vfx_choices[vfx_select.selected].duplicate(true)
    document.events[selected_event].anchor=Asset.EVENT_ANCHORS[event_anchor.selected]
    refresh(frame)
    info.text="Пресет VFX заменён."

func open_quick_vfx()->void:
    if selected_event<0 or selected_event>=document.events.size() or document.events[selected_event].kind!="vfx":
        info.text="Выбери VFX-маркер."
        return
    quick_dialog.open_for(document.events[selected_event].preset)

func apply_quick_vfx(value:Dictionary)->void:
    if selected_event<0 or selected_event>=document.events.size() or not VFX.valid(value):return
    remember()
    document.events[selected_event].preset=value.duplicate(true)
    refresh(frame)
    info.text="VFX обновлён. Ctrl+Z — отменить."

func render_vfx()->void:
    if fx_surface==null or fx_visible==null:return
    fx_surface.visible=fx_visible.button_pressed and document.kind=="action" and not is_bound()
    if not fx_surface.visible:return
    var clip:Dictionary={"duration":document.duration,"loop":document.get("loop",false),"easing":document.get("easing","linear"),"keys":[],"events":document.events}
    for key in document.keys:
        clip.keys.append({"t":key.t,"pose":{"angles":key.angles,"root":key.get("root",[0.,0.])},"easing":key.get("easing",document.get("easing","linear"))})
    var t:=clampf(float(frame-START)/60.,0.,document.duration)
    fx_preview.draw(fx_surface.painter,clip,t,Vector2(240,219),Vector2(280,193))
    fx_surface.present()

func load_reference(path:String)->void:
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null:
        info.text="Не удалось открыть референс."
        return
    var length:int=file.get_length()
    file.close()
    if length>32*1024*1024:
        info.text="Референс больше 32 МБ."
        return
    var im:=Image.new()
    if im.load(path)!=OK or im.is_empty():
        info.text="Не удалось прочитать изображение."
        return
    if maxi(im.get_width(),im.get_height())>4096:
        var ratio:float=4096./maxi(im.get_width(),im.get_height())
        im.resize(maxi(1,roundi(im.get_width()*ratio)),maxi(1,roundi(im.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
    reference_sprite.texture=ImageTexture.create_from_image(im)
    reference_name.text=path.get_file()
    reference_name.tooltip_text=path
    reference_visible.set_pressed_no_signal(true)
    reset_reference_view()
    info.text="Референс загружен (только просмотр)."

func clear_reference()->void:
    reference_sprite.texture=null
    reference_name.text="Нет изображения"
    reference_name.tooltip_text=""
    update_reference()

func reset_reference_view()->void:
    reference_opacity.set_value_no_signal(.35)
    reference_scale.set_value_no_signal(1.)
    reference_x.set_value_no_signal(0.)
    reference_y.set_value_no_signal(0.)
    update_reference()

func update_reference()->void:
    var texture:Texture2D=reference_sprite.texture
    reference_sprite.visible=texture!=null and reference_visible.button_pressed
    if texture==null:return
    var fit:float=minf(VIEW.size.x/texture.get_width(),VIEW.size.y/texture.get_height())
    reference_sprite.scale=Vector2.ONE*fit*reference_scale.value
    reference_sprite.position=VIEW.size*.5+Vector2(reference_x.value,reference_y.value)
    reference_sprite.modulate.a=reference_opacity.value

func side_id()->String:
    return "near" if release_side.selected==0 else "far"

func sync_release()->void:
    release_panel.visible=document.kind=="action" and not is_bound()
    if not release_panel.visible:return
    var r:Dictionary=document.get("release",{})
    var enabled:bool=r.has(side_id())
    var knots:Array=r.get(side_id(),[0.,.18,.75,1.])
    for i in 4:release_fields[i].set_value_no_signal(float(knots[i])*100.)
    release_state.text="Авторская нога в заданном окне" if enabled else "Сейчас опора полностью под Astra"
    release_remove.disabled=not enabled

func apply_release()->void:
    if document.kind!="action" or is_bound():return
    var side:String=side_id()
    var knots:Array=[]
    for field in release_fields:knots.append(field.value/100.)
    for i in range(1,4):
        if knots[i]<=knots[i-1]:
            info.text="Четыре фазы должны возрастать строго."
            return
    var d:Dictionary=document.duplicate(true)
    var channels:Array=["thigh_"+side,"knee_"+side,"foot_pitch_"+side]
    if not channels.all(func(id):return d.keys[0].angles.has(id)):
        # Sample the currently executed action only once, in increasing time.
        # Preserve all pre-existing authored angles. Add only absent leg channels.
        var probe=Asset.player(document,60)
        var tick:int=-1
        for k in d.keys:
            var target:int=START+roundi(float(k.t)*60.)
            while tick<target:
                tick+=1
                probe.step(command(tick))
            for id in channels:
                if not k.angles.has(id):k.angles[id]=clampf(float(probe.final_pose.angles.get(id,0.)),-360.,360.)
    var release:Dictionary=d.get("release",{})
    release[side]=knots
    d.release=release
    var error:String=Asset.problem(d)
    if error!="":
        info.text=error
        return
    remember()
    document=d
    refresh(frame)
    info.text="Нога под авторским контролем в заданном окне."

func remove_release()->void:
    var release:Dictionary=document.get("release",{})
    if not release.has(side_id()):return
    remember()
    release.erase(side_id())
    document.release=release
    refresh(frame)
    info.text="Опора возвращена Astra. Ключи ноги сохранены."

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
    if document.has("walk_role") and document.walk_role!="walk_idle" and index==document.keys.size()-1:index=0
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
    var d:Dictionary={"version":2,"id":id,"name":label.strip_edges(),"kind":"action","duration":duration,"fps":60,"easing":"linear","loop":false,"keys":[{"t":0.,"angles":angles.duplicate(true),"root":[0.,0.]},{"t":duration,"angles":angles.duplicate(true),"root":[0.,0.]}],"events":[],"goals":[]}
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
    if not onion_enabled or playing or player==null or ghost_raster==null or pose_tool.selected==1:return
    for i in 2:
        var t:int=clampi(frame+[-4,4][i],0,end_frame())
        if t==frame:continue
        if not ghost_cache.has(t):
            var probe=build_preview_player()
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

func button(row:Node,title:String,fn:Callable,hint:String="")->Button:
    var b:=Button.new()
    b.text=title
    b.tooltip_text=hint
    b.add_theme_font_size_override("font_size",12)
    row.add_child(b)
    b.pressed.connect(fn)
    return b

func bound_document(id:String,path:String)->Dictionary:
    if id in Asset.WALK_IDS:return WalkMotion.document(id)
    if id in Asset.TRAIN_IDS:return Punch.document(id)
    return Asset.read(path if FileAccess.file_exists(path) else Asset.DIR+id+".json")

func is_bound()->bool:
    return document.has("walk_role") or document.get("training_attack",false)

func open_motion(id:String):
    var path:=Asset.FOLDER+id+".json"
    var d:=bound_document(id,path)
    var error:=Asset.problem(d)
    if error=="" and d.id!=id:error="Имя файла расходится с id"
    if error!="":
        info.text="Загрузка: "+error
        return
    document=Asset.normalise(d)
    rotate_active=false
    root_drag_active=false
    if d.kind=="gait":pose_tool.select(0)
    elif is_bound():pose_tool.select(1)
    saved_signature=JSON.stringify(document)
    motion.select(ids.find(id))
    delete_motion_button.disabled=not can_delete_motion(id)
    selected=-1
    history.clear()
    redo_history.clear()
    playing=false
    refresh(0 if document.kind=="gait" else START)
    if is_bound():
        set_pose_tool(1)
        info.text="Сохрани движение и проверь в T. Стопы корректируются в исполнении."
    else:
        set_pose_tool(0 if d.kind=="gait" else pose_tool.selected)
        info.text="Крест — цель, круг — результат."

func end_frame()->int:
    if document.get("walk_role","")=="walk_idle":return START
    if document.has("walk_role"):return START+roundi(document.duration*60.)
    if document.kind=="gait":return 220
    return START+roundi(document.duration*60.)

func command(t:int)->Dictionary:
    if document.kind=="gait":return {"speed":1. if t<24 else (document.speed if t<132 else 0.)}
    return {"speed":preview_speed,"action":document.id if t==START else ""}

func build_preview_player():
    if is_bound():return WalkPreview.new(document)
    if document.kind=="gait":return Asset.player(document,60)
    var gait_doc:Dictionary=Asset.read(Asset.DIR+"sprint.json")
    return Asset.ensemble(gait_doc,[document],60)

func seek(value:int):
    playing=false
    update_play_button()
    simulate(value)

func simulate(value:int):
    value=clampi(value,0 if document.kind=="gait" else START,end_frame())
    rotate_active=false
    if not player or value<=frame:
        player=build_preview_player()
        frame=-1
    while frame<value:
        frame+=1
        player.step(command(frame))
    syncing=true
    timeline.value=frame
    syncing=false
    show_pose()

func refresh(value:int):
    # Cycle boundary is a linked key, not an independent pose.
    if document.has("walk_role") and document.walk_role!="walk_idle":
        var last:Dictionary=document.keys[0].duplicate(true)
        last.t=document.duration
        document.keys[-1]=last
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
        param.max_value=10.
        param.value=document.duration
    pose_controls.visible=document.kind=="action"
    var is_action:bool=document.kind=="action"
    var is_walk:bool=is_bound()
    pose_tool.set_item_disabled(0,is_walk)
    inspector.set_tab_disabled(1,is_walk)
    inspector.set_tab_disabled(4,is_walk)
    if is_walk and pose_tool.selected==0:pose_tool.select(1)
    if is_walk and inspector.current_tab in [1,4]:inspector.current_tab=2
    param.editable=not (is_walk and document.get("walk_role","")=="walk_idle")
    fps_select.visible=is_action and not (is_walk and document.get("walk_role","")=="walk_idle")
    easing_select.visible=is_action
    attack_role_select.visible=document.get("training_attack",false)
    if attack_role_select.visible:attack_role_select.select(AttackAdapt.ROLES.find(AttackAdapt.role(document)))
    landing_select.visible=document.get("training_attack",false) and not document.get("events",[]).is_empty() and str(document.events[0].anchor).begins_with("foot_")
    if landing_select.visible:landing_select.select(1 if AttackRecovery.policy(document)=="forward_land" else 0)
    loop_toggle.visible=is_action and not is_walk
    preview_speed_select.visible=is_action and not is_walk
    if is_action:
        fps_select.select([24,30,60].find(int(document.get("fps",60))))
        easing_select.select(Asset.EASING.find(str(document.get("easing","linear"))))
        loop_toggle.set_pressed_no_signal(bool(document.get("loop",false)))
        timeline.step=60./float(document.get("fps",60))
    else:timeline.step=1.
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
    sync_events()
    refresh_channel_tree()
    sync_release()
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
    sync_edit_pose()
    var rendered:bool=false
    if raster:
        var p:Dictionary=edit_pose if pose_tool.selected==1 and not edit_pose.is_empty() else player.final_pose
        var rig=pose_rig if pose_tool.selected==1 and not edit_pose.is_empty() else player.rig
        var parts:Array=body.make(rig.points,p.angles,rig.rotations.head)
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
    status.text="%s   ·   кадр %d   ·   %s"%[document.name,frame if document.kind=="gait" else frame-START,state]
    if not rendered:
        status.text+="  |  НЕТ НАТИВНОГО ТЕЛА — нужен полный пакет"
        sprite.hide()
    else:sprite.show()
    render_vfx()
    var joint:String=Asset.JOINTS[joints.selected]
    if player.goal_report.has(joint):
        var r:Dictionary=player.goal_report[joint]
        status.text+="   ·   %s   Δ %.2f"%[r.reason,at_joint(joint).distance_to(r.target)]
    frame_label.text=("%d / %d к."%[frame,end_frame()]) if document.kind=="gait" else ("%d к. · %.2f с"%[frame-START,float(frame-START)/60.])
    dirty_label.text="● Не сохранено" if JSON.stringify(document)!=saved_signature else "Сохранено"
    sync_key()
    sync_curve()
    sync_pose_hint()
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
    if pose_tool.selected==1 and not edit_pose.is_empty():
        var root_pos:=root_handle_position()
        draw_rect(Rect2(root_pos-Vector2(5,5),Vector2(10,10)),Color("#f0cf77"),false,2.)
    if not show_handles or pose_tool.selected==2:return
    if pose_tool.selected==1:
        draw_pose_bones()
        return
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
    if index<0 or index>=entries.size():return
    if lane==0 and index in [0,entries.size()-1]:return
    var t:=clampf((value-START)/60.,0.,document.duration)
    t=clampf(snappedf(t,1./float(document.get("fps",60))),0.,document.duration)
    if lane==0 and (t<=entries[index-1].t or t>=entries[index+1].t):return
    remember()
    entries[index].t=t
    refresh(START+roundi(t*60))

func seek_accent():
    if document.kind=="action":
        if document.get("walk_role","")=="walk_idle":
            seek(START)
            return
        seek(START+roundi((document.events[0].t if document.events.size() else document.duration*.45)*60))
        return
    seek(65)
    while frame<130 and not airborne():simulate(frame+1)

func _unhandled_input(event):
    if root_drag_active and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        finish_root_drag()
        return
    if root_drag_active and event is InputEventMouseMotion:
        update_root_drag(event.position,event.shift_pressed)
        return
    if rotate_active and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        finish_rotation()
        return
    if rotate_active and event is InputEventMouseMotion:
        rotate_to(event.position,event.shift_pressed)
        return
    if event is InputEventKey and UI.editor_shortcut(self,event):
        match UI.physical_key(event):
            KEY_ESCAPE:
                if rotate_active:cancel_rotation()
                elif root_drag_active:
                    root_drag_active=false
                    show_pose()
                else:request_exit()
            KEY_1:set_pose_tool(0)
            KEY_2:set_pose_tool(1)
            KEY_3:set_pose_tool(2)
            KEY_SPACE:
                if not rotate_active:toggle_play()
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
            if pose_tool.selected==1:
                start_rotation(event.position)
                return
            if pose_tool.selected!=0:return
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

func set_pose_tool(mode:int)->void:
    if rotate_active:cancel_rotation()
    if root_drag_active:finish_root_drag()
    dragging=false
    if mode==0 and is_bound():mode=1
    if mode==1 and document.kind!="action":
        mode=0
        info.text="Бег редактируется целями и параметрами."
    pose_tool.select(mode)
    playing=false
    if mode==1:
        channel_mode.select(1)
        target_list.hide()
        channel_tree.show()
        inspector.current_tab=2
        if frame<START or frame>START+roundi(float(document.duration)*60.):
            seek(START)
            return
    elif mode==0:
        channel_mode.select(0)
        target_list.show()
        channel_tree.hide()
    show_pose()

func sampled_pose(t:float)->Dictionary:
    var keys:Array=[]
    for k in document.keys:
        keys.append({"t":k.t,"pose":{"angles":k.angles,"root":k.get("root",[0.,0.])},"easing":k.get("easing",document.get("easing","linear"))})
    return Clips.sample({"duration":document.duration,"loop":false,"easing":document.get("easing","linear"),"keys":keys},t,false)

func sampled_angles(t:float)->Dictionary:
    return sampled_pose(t).angles

func sync_edit_pose()->void:
    if document.kind!="action" or pose_tool.selected!=1:
        edit_pose={}
        return
    var t:float=clampf(float(frame-START)/60.,0.,float(document.duration))
    var authored:Dictionary=sampled_pose(t)
    edit_pose=player.final_pose.duplicate(true)
    if is_bound():edit_pose=authored.duplicate(true)
    else:
        var base:Dictionary=player.gait.intent().pose
        edit_pose.root=base.root.duplicate()
        edit_pose.angles.merge(authored.angles,true)
        edit_pose.root[0]+=authored.root[0]
        edit_pose.root[1]+=authored.root[1]
    if rotate_active:edit_pose.angles[rotate_channel]=clampf(rotate_initial+rotate_delta,-360.,360.)
    if root_drag_active:
        edit_pose.root[0]+=root_drag_delta.x
        edit_pose.root[1]+=root_drag_delta.y
    pose_rig.evaluate(edit_pose)

func sync_pose_hint()->void:
    if is_bound() and pose_tool.selected==2:
        pose_hint.text="Исполнение T · контакт стоп с землёй"
        return
    match pose_tool.selected:
        0:pose_hint.text="IK: потяни точку · колесо: масштаб"
        1:pose_hint.text="FK: кость — вращение · квадрат таза — перенос · Shift — привязка"
        2:pose_hint.text="Исполнение Astra · контекст стойка / ходьба / бег"

func editable_bone(id:String)->bool:
    if document.kind!="action" or not document.keys[0].angles.has(id):return false
    if id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_pitch_"):
        return is_bound() or document.get("release",{}).has(id.get_slice("_",id.get_slice_count("_")-1))
    return id in BONE_END or id=="head"

func bone_points(id:String)->Array:
    var joint:String=id
    if id.begins_with("foot_pitch_"):
        joint="foot_"+id.get_slice("_",2)
        var p:Vector2=pose_rig.point(joint)
        var toe:Vector2=p+Vector2.RIGHT.rotated(deg_to_rad(float(edit_pose.angles.get(id,0.))))*6.
        return [ORIGIN+p*view_zoom,ORIGIN+toe*view_zoom]
    var a:Vector2=pose_rig.point(joint)
    var b:Vector2=pose_rig.point(BONE_END[id]) if BONE_END.has(id) else a+Vector2(0,-5).rotated(float(pose_rig.rotations[joint]))
    return [ORIGIN+a*view_zoom,ORIGIN+b*view_zoom]

func selected_channel()->String:
    return str(key_channels.get_item_metadata(key_channels.selected)) if key_channels.selected>=0 else ""

func draw_pose_bones()->void:
    if edit_pose.is_empty():return
    var selected_id:String=selected_channel()
    for id in document.keys[0].angles:
        if not editable_bone(id):continue
        var pts:Array=bone_points(id)
        var a:Vector2=pts[0]
        var b:Vector2=pts[1]
        if not VIEW.has_point(a) or not VIEW.has_point(b):continue
        var active:bool=id==selected_id
        var c:Color=Color("#ffcf62") if active else Color("#91c6d5")
        draw_line(a,b,c,3. if active else 1.5,true)
        draw_circle(a,5. if active else 3.,c)
        draw_circle(b,3.,c)
        if active:
            draw_arc(a,18.,0.,TAU,48,Color("#ffcf62"),1.5,true)
            if rotate_active:
                draw_string(ThemeDB.fallback_font,a+Vector2(20,-9),"%.1f°"%clampf(rotate_initial+rotate_delta,-360.,360.),HORIZONTAL_ALIGNMENT_LEFT,-1,12,c)

func root_handle_position()->Vector2:
    return ORIGIN+pose_rig.point("hips")*view_zoom

func start_root_drag(mouse:Vector2)->void:
    if document.kind!="action":return
    playing=false
    root_drag_key=key_at_frame()
    root_drag_time=float(document.keys[root_drag_key].t) if root_drag_key>=0 else clampf(snappedf(float(frame-START)/60.,1./float(document.get("fps",60))),0.,float(document.duration))
    root_drag_initial=Vector2(float(sampled_pose(root_drag_time).root[0]),float(sampled_pose(root_drag_time).root[1]))
    root_drag_start=mouse
    root_drag_delta=Vector2.ZERO
    root_drag_changed=false
    root_drag_active=true
    inspector.current_tab=2
    show_pose()

func update_root_drag(mouse:Vector2,snap:bool=false)->void:
    if not root_drag_active:return
    root_drag_delta=(mouse-root_drag_start)/view_zoom
    if snap:root_drag_delta=root_drag_delta.snapped(Vector2(.5,.5))
    root_drag_changed=root_drag_delta.length()>.02
    show_pose()

func finish_root_drag()->void:
    if not root_drag_active:return
    var delta:=root_drag_delta
    var t:=root_drag_time
    var existing:=root_drag_key
    root_drag_active=false
    if root_drag_changed:
        remember()
        var pose_value:Dictionary=sampled_pose(t)
        var root_value:Vector2=Vector2(float(pose_value.root[0]),float(pose_value.root[1]))+delta
        root_value.x=clampf(root_value.x,-40.,40.)
        root_value.y=clampf(root_value.y,-40.,40.)
        if existing>=0:document.keys[existing].root=[root_value.x,root_value.y]
        elif document.keys.size()<600:document.keys.append({"t":t,"angles":pose_value.angles.duplicate(true),"root":[root_value.x,root_value.y]})
        else:
            history.pop_back()
            info.text="Лимит 600 ключей."
            refresh(frame)
            return
        document.keys.sort_custom(func(a,b):return a.t<b.t)
        refresh(START+roundi(t*60.))
        info.text="Перемещение корня записано в ключ."
    else:show_pose()

func start_rotation(mouse:Vector2)->void:
    if document.kind!="action" or frame<START or frame>START+roundi(float(document.duration)*60.):return
    if mouse.distance_to(root_handle_position())<=9.:
        start_root_drag(mouse)
        return
    var chosen:String=""
    var best:float=12.
    var preferred:String=selected_channel()
    for id in document.keys[0].angles:
        if not editable_bone(id):continue
        var pts:Array=bone_points(id)
        var p:Vector2=Geometry2D.get_closest_point_to_segment(mouse,pts[0],pts[1])
        var d:float=mouse.distance_to(p)
        if mouse.distance_to(pts[0])<7.:continue
        if id==preferred:d-=3.
        if d<best:
            best=d
            chosen=id
    if chosen=="":
        info.text="Выбери доступную кость за линию, не за центр вращения."
        return
    playing=false
    rotate_channel=chosen
    rotate_key=key_at_frame()
    rotate_time=float(document.keys[rotate_key].t) if rotate_key>=0 else clampf(snappedf(float(frame-START)/60.,1./float(document.get("fps",60))),0.,float(document.duration))
    if rotate_key<0 and document.keys.size()>=600:
        info.text="Лимит 600 ключей."
        return
    rotate_angles=document.keys[rotate_key].angles.duplicate(true) if rotate_key>=0 else sampled_angles(rotate_time)
    rotate_initial=float(rotate_angles[chosen])
    rotate_delta=0.
    rotate_changed=false
    rotate_pivot=bone_points(chosen)[0]
    rotate_last=(mouse-rotate_pivot).angle()
    rotate_active=true
    for i in key_channels.item_count:
        if key_channels.get_item_metadata(i)==chosen:key_channels.select(i)
    inspector.current_tab=2
    sync_key()
    sync_curve()
    queue_redraw()

func rotate_to(mouse:Vector2,snap:bool=false)->void:
    if not rotate_active or mouse.distance_to(rotate_pivot)<5.:return
    var a:float=(mouse-rotate_pivot).angle()
    rotate_delta+=rad_to_deg(wrapf(a-rotate_last,-PI,PI))
    rotate_last=a
    var raw:float=rotate_delta
    if snap:rotate_delta=snappedf(rotate_initial+raw,5.)-rotate_initial
    rotate_changed=absf(rotate_delta)>.05
    show_pose()
    rotate_delta=raw

func finish_rotation()->void:
    if not rotate_active:return
    var angle:float=float(edit_pose.angles.get(rotate_channel,rotate_initial))
    rotate_active=false
    if rotate_changed and absf(angle-rotate_initial)>.05:
        remember()
        rotate_angles[rotate_channel]=angle
        if rotate_key>=0:document.keys[rotate_key].angles=rotate_angles
        else:
            var root:Array=sampled_pose(rotate_time).root
            document.keys.append({"t":rotate_time,"angles":rotate_angles,"root":root})
            document.keys.sort_custom(func(a,b):return a.t<b.t)
        refresh(frame)
        info.text="Ключ записан. 3 — проверить исполнение."
    else:show_pose()

func cancel_rotation()->void:
    rotate_active=false
    show_pose()
    info.text="Вращение отменено."

func begin_drag(joint:String):
    if is_bound():return
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
    if syncing or document.get("walk_role","")=="walk_idle":return
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
    if document.kind!="action":return
    if document.get("walk_role","")=="walk_idle":
        remember()
        document.keys[0].angles=(edit_pose if pose_tool.selected==1 else player.final_pose).angles.duplicate(true)
        refresh(START)
        return
    var t:=clampf((frame-START)/60.,0.,document.duration)
    t=clampf(snappedf(t,1./float(document.get("fps",60))),0.,document.duration)
    if document.has("walk_role") and is_equal_approx(t,float(document.duration)):t=0.
    var angles:Dictionary={}
    var sampled:Dictionary=sampled_pose(t)
    for id in document.keys[0].angles:angles[id]=edit_pose.angles[id] if pose_tool.selected==1 else (player.final_pose.angles[id] if player.action!="" else sampled.angles[id])
    var root:Array=sampled.root.duplicate()
    remember()
    for k in document.keys:
        if absf(t-k.t)<.00001:
            k.angles=angles
            k.root=root
            refresh(frame)
            return
    if document.keys.size()<600:
        document.keys.append({"t":t,"angles":angles,"root":root})
        document.keys.sort_custom(func(a,b):return a.t<b.t)
    refresh(frame)

func toggle_contact():
    if is_bound():return
    if player.action=="" or document.get("loop",false):return
    var id:String=Asset.JOINTS[joints.selected]
    if not (id.begins_with("hand") or id.begins_with("foot")):return
    var t:=clampf((frame-START)/60.,0.,document.duration)
    remember()
    for i in document.events.size():
        if document.events[i].kind=="strike" and roundi(document.events[i].t*60)==roundi(t*60) and document.events[i].anchor==id:
            document.events.remove_at(i)
            refresh(frame)
            return
    if document.events.size()<32:document.events.append({"t":t,"kind":"strike","anchor":id})
    refresh(frame)

func copy_goal():
    if selected>=0:clip_board=document.goals[selected].duplicate(true)

func paste_goal():
    if is_bound():return
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
    document=Asset.normalise(document)
    var err:=Asset.persist(document)
    if err==OK:saved_signature=JSON.stringify(document)
    info.text="Сохранено: "+document.id+".json" if err==OK else error_string(err)
    show_pose()

func can_delete_motion(id:String)->bool:
    return id.is_valid_identifier() and not Asset.IDS.has(id) and not Asset.WALK_IDS.has(id) and not Asset.TRAIN_IDS.has(id) and ids.has(id) and FileAccess.file_exists(Asset.FOLDER+id+".json")

func ask_delete_motion()->void:
    if not can_delete_motion(str(document.id)):return
    playing=false
    delete_motion_id=document.id
    delete_motion_dialog.dialog_text="Удалить «"+str(document.name)+"» и все несохранённые изменения этого движения? Встроенные анимации не затрагиваются."
    delete_motion_dialog.popup_centered(Vector2i(420,150))

func delete_user_motion(id:String)->bool:
    if not can_delete_motion(id) or document.id!=id:return false
    var index:int=ids.find(id)
    var err:=DirAccess.remove_absolute(ProjectSettings.globalize_path(Asset.FOLDER+id+".json"))
    if err!=OK:
        info.text="Не удалось удалить: "+error_string(err)
        return false
    playing=false
    ids.remove_at(index)
    motion.remove_item(index)
    delete_motion_id=""
    open_motion(ids[clampi(index-1,0,ids.size()-1)])
    info.text="Пользовательское движение удалено."
    return true

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
        if loop_play and document.kind=="action":
            simulate(START+posmod(next-START,maxi(1,end_frame()-START)))
        elif loop_play:simulate(next%(end_frame()+1))
        else:
            simulate(mini(next,end_frame()))
            if next>=end_frame():playing=false;update_play_button()
