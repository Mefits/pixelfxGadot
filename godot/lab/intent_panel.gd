extends PanelContainer
const UI=preload("res://lab/ui_ru.gd")
## Compact editor for the physical attack track, using the actual lab for playback.
const TRACK=preload("res://addons/creature/motion_track.gd")
var creature
var draft: Dictionary
var chosen: int=0
var keys: OptionButton
var fields: Dictionary={}
var status: Label
var sync: bool=false

func _init(c) -> void:
    creature=c
    draft=c.attack.track.duplicate(true)

func _ready() -> void:
    position=Vector2(640,76)
    size=Vector2(308,402)
    var compact:=Theme.new()
    compact.default_font_size=14
    theme=compact
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("#202c3b")
    style.content_margin_left=10
    style.content_margin_right=10
    style.content_margin_top=8
    style.content_margin_bottom=8
    add_theme_stylebox_override("panel",style)
    var scroll:=ScrollContainer.new()
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroll)
    var col:=VBoxContainer.new()
    col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation",2)
    scroll.add_child(col)
    var title:=Label.new()
    title.text="АТАКА / параметры движения"
    col.add_child(title)
    keys=OptionButton.new()
    col.add_child(keys)
    keys.item_selected.connect(func(i:int):chosen=i;_refresh())
    for spec in [["t","Время ключа, с",0.0,3.0,.01],["x","Вылет X",-1.5,1.5,.05],["y","Вылет Y",-1.5,1.5,.05],["tilt","Наклон, рад",-1.5,1.5,.05],["speed","Скорость рывка",-250.0,250.0,5.0],["rear","Высота таза",-8.0,8.0,.5],["duration","Длительность",.2,3.0,.01],["active_from","Начало удара",0.0,3.0,.01],["active_to","Конец удара",0.0,3.0,.01]]:
        var row:=HBoxContainer.new()
        col.add_child(row)
        var label:=Label.new()
        label.text=spec[1]
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        row.add_child(label)
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=86
        row.add_child(spin)
        fields[spec[0]]=spin
        var key: String=spec[0]
        spin.value_changed.connect(func(v:float):_edit(key,v))
    var row:=HBoxContainer.new()
    col.add_child(row)
    _button(row,"+ Ключ",_insert)
    _button(row,"− Ключ",_remove)
    _button(row,"Проверить",preview)
    var row2:=HBoxContainer.new()
    col.add_child(row2)
    _button(row2,"Сохранить",_save)
    _button(row2,"Загрузить",func():draft=TRACK.load_track();chosen=0;_refresh())
    _button(row2,"Сброс",func():draft=TRACK.defaults();chosen=0;_refresh())
    var row3:=HBoxContainer.new()
    col.add_child(row3)
    _button(row3,"Закрыть",queue_free)
    status=Label.new()
    status.add_theme_font_size_override("font_size",12)
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    col.add_child(status)
    status.text="X/Y — доли длины лапы. Проверка запускает настоящую атаку."
    _refresh()

func _button(row: Control,label: String,cb: Callable) -> void:
    var b:=Button.new()
    b.text=label
    row.add_child(b)
    b.pressed.connect(cb)

func _refresh() -> void:
    sync=true
    keys.clear()
    for k in draft.keys:keys.add_item("Ключ %.2f с"%k.t)
    chosen=clampi(chosen,0,draft.keys.size()-1)
    keys.select(chosen)
    for name in fields:
        fields[name].value=float(draft[name] if draft.has(name) else draft.keys[chosen][name])
    fields.t.editable=chosen>0 and chosen<draft.keys.size()-1
    sync=false

func _edit(key: String,v: float) -> void:
    if sync:return
    if key=="duration":
        var ratio: float=v/float(draft.duration)
        for k in draft.keys:k.t*=ratio
        draft.active_from*=ratio
        draft.active_to*=ratio
        draft.duration=v
    elif draft.has(key):
        draft[key]=v
    elif key=="t":
        if chosen>0 and chosen<draft.keys.size()-1:
            draft.keys[chosen].t=clampf(v,float(draft.keys[chosen-1].t)+.001,float(draft.keys[chosen+1].t)-.001)
    else:draft.keys[chosen][key]=v
    if key in ["t","duration"]:_refresh()

func _insert() -> void:
    if draft.keys.size()>=64:return
    var i: int=mini(chosen,draft.keys.size()-2)
    var t: float=(float(draft.keys[i].t)+float(draft.keys[i+1].t))*.5
    var s: Dictionary=TRACK.sample(draft,t)
    draft.keys.insert(i+1,{"t":t,"x":s.claw.x,"y":s.claw.y,"tilt":s.tilt,"speed":s.speed,"rear":s.rear})
    chosen=i+1
    _refresh()

func _remove() -> void:
    if chosen<=0 or chosen>=draft.keys.size()-1:return
    draft.keys.remove_at(chosen)
    chosen-=1
    _refresh()

func preview() -> void:
    if not creature.attack.set_track(draft):
        status.text="Неверное время или атака ещё идёт."
        return
    if creature.surface.active or creature.grip_index>=0 or not creature.limbs.enabled:
        status.text="Встань на пол, включи лапы."
        return
    creature.attack_requested=true
    status.text="Запущена физическая атака."

func _save() -> void:
    if TRACK.save_track(draft):
        var applied: bool=creature.attack.set_track(draft)
        status.text="Сохранено и применено." if applied else "Сохранено. Проверь после текущей атаки."
    else:status.text="Неверные параметры. Проверь интервал попадания."
