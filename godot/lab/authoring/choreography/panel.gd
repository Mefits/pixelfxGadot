extends Window
const Player=preload("player.gd")
const Training=preload("res://lab/training_control.gd")
const Idle=preload("res://lab/spatial_lab/spatial_idle_013.gd")
const Body=preload("res://lab/spatial_lab/spatial_body.gd")
const CFG=preload("res://lab/hybrid_studio.gd").CFG
const DIR="res://lab/authoring/choreography/"
var doc:Dictionary
var ids:=PackedStringArray()
var chooser:=OptionButton.new()
var key_picker:=OptionButton.new()
var field:=OptionButton.new()
var value_edit:=SpinBox.new()
var support:=OptionButton.new()
var source:=CodeEdit.new()
var frame:=HSlider.new()
var picture:=TextureRect.new()
var message:=Label.new()
var actor=Player.new()
var idle=Idle.new()
var skin=Body.new()
var raster
var now:Dictionary
var prior:Dictionary
var playing:=false

func _ready():
    title="Пространственная хореография · M"
    size=Vector2i(900,520)
    close_requested.connect(hide)
    var layout:=VBoxContainer.new()
    add_child(layout)
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var row:=HBoxContainer.new()
    layout.add_child(row)
    row.add_child(chooser)
    for id in ["wheel","hook"]:ids.append(id)
    var dir:=DirAccess.open(Player.Asset.FOLDER)
    if dir:
        for file in dir.get_files():
            if file.ends_with(".json"):
                var id:=file.get_basename()
                if not ids.has(id) and Player.Asset.read(Player.Asset.FOLDER+file).has("spatial_version"):ids.append(id)
    for id in ids:chooser.add_item(id)
    chooser.item_selected.connect(open_doc)
    for item in [["Применить",apply],["Сохранить",save_doc],["Загрузить",reload_doc],["▶ / пауза",toggle]]:
        var b:=Button.new()
        b.text=item[0]
        b.pressed.connect(item[1])
        row.add_child(b)
    var inspector:=HBoxContainer.new()
    layout.add_child(inspector)
    for control in [key_picker,field,value_edit,support]:inspector.add_child(control)
    for name in ["tick","root.x","root.y"]+Player.TRACK+Player.Asset.CHANNELS+Player.Asset.LEG_CHANNELS:field.add_item(name)
    for name in ["near","far","air"]:support.add_item(name)
    value_edit.min_value=-1440
    value_edit.max_value=1440
    value_edit.step=.01
    key_picker.item_selected.connect(func(_i):select_key())
    field.item_selected.connect(func(_i):select_key())
    var edit:=Button.new()
    edit.text="Записать ключ"
    inspector.add_child(edit)
    edit.pressed.connect(write_key)
    var marker:=Button.new()
    marker.text="Контакт сюда"
    inspector.add_child(marker)
    marker.pressed.connect(move_marker)
    var split:=HSplitContainer.new()
    layout.add_child(split)
    split.size_flags_vertical=Control.SIZE_EXPAND_FILL
    split.add_child(source)
    source.custom_minimum_size.x=420
    split.add_child(picture)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    layout.add_child(frame)
    frame.step=1
    frame.value_changed.connect(seek)
    layout.add_child(message)
    var base=Training.new().walker.pose
    idle.mode=3
    idle.setup(base)
    idle.idle(16)
    prior=Player.Entry.sample(idle.rig,base)
    idle.idle(17)
    now=Player.Entry.sample(idle.rig,base)
    if ClassDB.class_exists("PixelFXBodyRaster"):raster=ClassDB.instantiate("PixelFXBodyRaster")
    open_doc(0)

func open_doc(index:int):
    var id=ids[index]
    var d:=Player.Asset.read(Player.Asset.FOLDER+id+".json")
    if d.is_empty():d=Player.Asset.read(DIR+id+".json")
    source.text=JSON.stringify(d,"  ",false,true)
    apply()

func reload_doc():open_doc(chooser.selected)

func apply()->bool:
    var parsed=JSON.parse_string(source.text)
    var err:=Player.problem(parsed) if parsed is Dictionary else "Неверный JSON"
    if err!="":
        message.text=err
        playing=false
        return false
    doc=parsed
    var playhead:=frame.value
    var index:=maxi(0,key_picker.selected)
    key_picker.clear()
    for k in doc.keys:key_picker.add_item("%d · %s"%[roundi(k.t*60),k.space.phase])
    key_picker.select(mini(index,doc.keys.size()-1))
    select_key()
    frame.max_value=roundi(doc.duration*60.)
    frame.set_value_no_signal(clampf(playhead,0,frame.max_value))
    seek(frame.value)
    return true

func save_doc():
    if not apply():return
    var err:=Player.Asset.persist(doc)
    if err==OK and not ids.has(doc.id):
        ids.append(doc.id)
        chooser.add_item(doc.id)
    if err==OK:chooser.select(ids.find(doc.id))
    message.text="Сохранено · "+doc.id if err==OK else error_string(err)

func seek(value:float):
    if doc.is_empty():return
    actor.start(doc,now,prior,1)
    for i in int(value)+1:
        if not actor.step():
            message.text="Недостижимая опора · такт "+str(i)
            playing=false
            return
    draw_pose()

func draw_pose():
    message.text="%s · %d / %d · опора %s"%[actor.phase,actor.age,actor.frames.size()-1,actor.side]
    if raster:
        var result:Dictionary=raster.render(CFG,skin.make(actor.rig,actor.art))
        if result.get("ok",false):picture.texture=ImageTexture.create_from_image(Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba))
    else:message.text+=" · нужен PixelFXBodyRaster"

func toggle():
    if actor.age>=actor.frames.size()-1:frame.value=0
    playing=not playing

func _physics_process(_delta):
    if visible and playing:
        if actor.step():
            frame.set_value_no_signal(actor.age)
            draw_pose()
        else:playing=false

func select_key():
    if doc.is_empty() or key_picker.selected<0:return
    var k:Dictionary=doc.keys[key_picker.selected]
    var name:=field.get_item_text(field.selected)
    var val:float
    match name:
        "tick":val=roundi(k.t*60.)
        "root.x":val=k.root[0]
        "root.y":val=k.root[1]
        _:
            val=k.space[name] if name in Player.TRACK else k.angles.get(name,0.)
    value_edit.value=val
    support.select(["near","far","air"].find(k.space.support))
    frame.value=roundi(k.t*60.)

func write_key():
    var next:=doc.duplicate(true)
    var k:Dictionary=next.keys[key_picker.selected]
    var name:=field.get_item_text(field.selected)
    match name:
        "tick":
            k.t=roundi(value_edit.value)/60.
            if key_picker.selected==next.keys.size()-1:next.duration=k.t
        "root.x":k.root[0]=value_edit.value
        "root.y":k.root[1]=value_edit.value
        _:
            if name in Player.TRACK:k.space[name]=value_edit.value
            else:
                for key in next.keys:
                    if not key.angles.has(name):key.angles[name]=0.
                k.angles[name]=value_edit.value
    k.space.support=support.get_item_text(support.selected)
    source.text=JSON.stringify(next,"  ",false,true)
    apply()

func move_marker():
    if doc.events.is_empty():return
    var next:=doc.duplicate(true)
    next.events[0].t=frame.value/60.
    source.text=JSON.stringify(next,"  ",false,true)
    apply()
