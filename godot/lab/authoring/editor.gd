extends Node2D
const Asset=preload("asset.gd")
const Goals=preload("goals.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const ORIGIN=Vector2(302,345)
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
var motion:OptionButton
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
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position=ORIGIN-Vector2(240,219)*ZOOM/3.
    sprite.scale=Vector2.ONE*ZOOM/3.
    sprite.z_index=-1
    add_child(sprite)
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")
    var side:=VBoxContainer.new()
    side.position=Vector2(608,10)
    side.custom_minimum_size.x=340
    side.add_theme_constant_override("separation",3)
    add_child(side)
    var title:=Label.new()
    title.text="Мастерская движений"
    title.add_theme_font_size_override("font_size",22)
    side.add_child(title)
    motion=OptionButton.new()
    side.add_child(motion)
    var directory:=DirAccess.open(Asset.FOLDER)
    if directory:
        for file in directory.get_files():
            var id:String=file.get_basename()
            if file.ends_with(".json") and id.is_valid_identifier() and not ids.has(id):ids.append(id)
    for id in ids:motion.add_item(id)
    motion.item_selected.connect(func(i):open_motion(ids[i]))
    joints=OptionButton.new()
    for id in Asset.JOINTS:joints.add_item(id)
    side.add_child(joints)
    goal_list=OptionButton.new()
    side.add_child(goal_list)
    goal_list.item_selected.connect(func(i):select_goal(i-1))
    strength=field(side,"Сила",0,1,.05,1.)
    priority=field(side,"Приоритет",0,9,1,1)
    width=field(side,"Радиус фазы",.01,1,.01,.20)
    for control in [strength,priority,width]:control.value_changed.connect(update_goal)
    param_choice=OptionButton.new()
    side.add_child(param_choice)
    param_choice.item_selected.connect(choose_param)
    param=SpinBox.new()
    param.step=.01
    side.add_child(param)
    param.value_changed.connect(change_param)
    var row:=HBoxContainer.new()
    side.add_child(row)
    button(row,"Копия цели",copy_goal)
    button(row,"Вставить",paste_goal)
    button(row,"Удалить",erase_goal)
    row=HBoxContainer.new()
    side.add_child(row)
    button(row,"Сохранить",save_file)
    button(row,"Загрузить",func():open_motion(document.id))
    button(row,"Отмена",undo)
    row=HBoxContainer.new()
    side.add_child(row)
    button(row,"Новое из текущего",duplicate_motion)
    button(row,"Меню",func():get_tree().change_scene_to_file("res://lab/main.tscn"))
    info=Label.new()
    info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    info.custom_minimum_size=Vector2(335,50)
    side.add_child(info)
    var controls:=HBoxContainer.new()
    controls.position=Vector2(14,421)
    add_child(controls)
    button(controls,"▶ / Ⅱ",func():playing=not playing)
    button(controls,"−1",func():seek(maxi(0,frame-1)))
    button(controls,"+1",func():seek(mini(end_frame(),frame+1)))
    button(controls,"Полёт / акцент",seek_accent)
    pose_controls=HBoxContainer.new()
    pose_controls.position=Vector2(14,376)
    add_child(pose_controls)
    button(pose_controls,"Записать позу",key_pose)
    button(pose_controls,"± Контакт",toggle_contact)
    timeline=preload("res://lab/pose_timeline.gd").new()
    timeline.position=Vector2(18,454)
    timeline.size=Vector2(565,40)
    timeline.step=1
    timeline.marker_moved.connect(move_marker)
    add_child(timeline)
    timeline.value_changed.connect(func(v):if not syncing:seek(roundi(v)))
    status=Label.new()
    status.position=Vector2(18,495)
    add_child(status)
    open_motion(ids[0])

func field(parent:Control,title:String,lo:float,hi:float,step:float,initial:float)->SpinBox:
    var row:=HBoxContainer.new()
    parent.add_child(row)
    var l:=Label.new()
    l.text=title
    l.custom_minimum_size.x=145
    row.add_child(l)
    var spin:=SpinBox.new()
    spin.min_value=lo
    spin.max_value=hi
    spin.step=step
    spin.value=initial
    row.add_child(spin)
    return spin

func button(row:Control,title:String,fn:Callable):
    var b:=Button.new()
    b.text=title
    row.add_child(b)
    b.pressed.connect(fn)

func open_motion(id:String):
    var path:=Asset.FOLDER+id+".json"
    var d:=Asset.read(path if FileAccess.file_exists(path) else Asset.DIR+id+".json")
    var error:=Asset.problem(d)
    if error!="":
        info.text="Загрузка: "+error
        return
    document=d
    selected=-1
    history.clear()
    playing=false
    refresh(0)
    info.text="Перетащи цветную точку. Крест — цель, круг — результат."

func end_frame()->int:
    return 220 if document.kind=="gait" else START+ceili(document.duration*60.)+22

func command(t:int)->Dictionary:
    if document.kind=="gait":return {"speed":1. if t<24 else (document.speed if t<132 else 0.)}
    return {"speed":0.,"action":document.id if t==START else ""}

func seek(value:int):
    playing=false
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
    for g in document.goals:goal_list.add_item("%s · %.2f · %s"%[g.joint,g.center,g.clock])
    timeline.max_value=end_frame()
    timeline.clip={"keys":[],"events":[]}
    if document.kind=="action":
        for k in document.keys:timeline.clip.keys.append({"t":START+k.t*60})
        for e in document.events:timeline.clip.events.append({"t":START+e.t*60,"kind":e.kind})
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
    strength.value=g.weight
    priority.value=g.priority
    width.value=g.width
    syncing=was

func show_pose():
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
            if sprite.texture:sprite.texture.update(im)
            else:sprite.texture=ImageTexture.create_from_image(im)
    var state:String="стойка" if player.stopped else ("полёт" if airborne() else "опора")
    if player.action!="":state=player.action
    status.text="%s   ·   тик %d   ·   %s"%[document.name,frame,state]
    var joint:String=Asset.JOINTS[joints.selected]
    if player.goal_report.has(joint):
        var r:Dictionary=player.goal_report[joint]
        status.text+="   ·   %s   Δ %.2f"%[r.reason,at_joint(joint).distance_to(r.target)]
    queue_redraw()

func airborne()->bool:
    return not player.paths[0].stance and not player.paths[1].stance

func at_joint(joint:String)->Vector2:
    if joint.begins_with("foot"):return player.anchors[joint]-Vector2.RIGHT*player.gait.travel
    return player.rig.point(joint)

func _draw():
    if not player:return
    draw_line(Vector2(12,ORIGIN.y),Vector2(590,ORIGIN.y),Color("#73858e"))
    for j in Asset.JOINTS:
        draw_circle(ORIGIN+at_joint(j)*ZOOM,4.,Color("#ffcf62") if j==Asset.JOINTS[joints.selected] else Color("#85c5c1"))
    for j in player.goal_report:
        var v:Vector2=ORIGIN+player.goal_report[j].target*ZOOM
        draw_line(v-Vector2(6,0),v+Vector2(6,0),Color.CORAL,2)
        draw_line(v-Vector2(0,6),v+Vector2(0,6),Color.CORAL,2)
        draw_line(v,ORIGIN+at_joint(j)*ZOOM,Color.CORAL)

func move_marker(lane:int,index:int,value:float):
    if document.kind!="action":return
    var entries:Array=document.keys if lane==0 else document.events
    if lane==0 and index in [0,entries.size()-1]:return
    var t:=clampf((roundf(value)-START)/60.,0.,document.duration)
    if lane==0 and (t<=entries[index-1].t or t>=entries[index+1].t):return
    history.append(document.duplicate(true))
    entries[index].t=t
    refresh(START+roundi(t*60))

func seek_accent():
    if document.kind=="action":
        seek(START+roundi((document.events[0].t if document.events.size() else document.duration*.45)*60))
        return
    seek(65)
    while frame<130 and not airborne():simulate(frame+1)

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_SPACE:playing=not playing
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_Z:
                if event.ctrl_pressed:undo()
            KEY_S:
                if event.ctrl_pressed:save_file()
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if not event.pressed:
            dragging=false
        elif Rect2(0,0,600,414).has_point(event.position):
            var best:=18.
            var id:=""
            for j in Asset.JOINTS:
                var distance:float=event.position.distance_to(ORIGIN+at_joint(j)*ZOOM)
                if distance<best:
                    best=distance
                    id=j
            if id!="":begin_drag(id)
    if event is InputEventMouseMotion and dragging:drag_to((event.position-ORIGIN)/ZOOM)

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
    dragging=true

func drag_to(point:Vector2):
    if not dragging:return
    if not gesture.is_empty():
        history.append(gesture)
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
    history.append(document.duplicate(true))
    var g:Dictionary=document.goals[selected]
    g.weight=strength.value
    g.priority=int(priority.value)
    g.width=width.value
    refresh(frame)

func change_param(value:float):
    if syncing:return
    history.append(document.duplicate(true))
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
    history.append(document.duplicate(true))
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
    if id.begins_with("elbow"):return
    var t:=clampf((frame-START)/60.,0.,document.duration)
    history.append(document.duplicate(true))
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
    history.append(document.duplicate(true))
    var g:=clip_board.duplicate(true)
    if document.kind=="action":g.clock="action"
    elif g.clock=="action":g.clock="cycle"
    document.goals.append(g)
    selected=document.goals.size()-1
    refresh(frame)

func erase_goal():
    if selected<0:return
    history.append(document.duplicate(true))
    document.goals.remove_at(selected)
    selected=-1
    refresh(frame)

func undo():
    if history.is_empty():return
    document=history.pop_back()
    selected=-1
    refresh(frame)

func save_file():
    var err:=Asset.persist(document)
    info.text="Сохранено: "+document.id+".json" if err==OK else error_string(err)

func duplicate_motion():
    var d:=document.duplicate(true)
    var index:=1
    while ids.has("motion_%d"%index):index+=1
    d.id="motion_%d"%index
    d.name=d.name+" · "+str(index)
    if Asset.persist(d)!=OK:return
    ids.append(d.id)
    motion.add_item(d.id)
    motion.select(ids.size()-1)
    open_motion(d.id)

func _process(delta:float):
    if not playing:return
    clock+=delta
    var steps:=floori(clock*60.)
    if steps>0:
        clock-=steps/60.
        simulate((frame+steps)%(end_frame()+1))
