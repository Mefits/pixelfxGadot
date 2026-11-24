extends ConfirmationDialog
const A=preload("res://addons/creature/ability.gd")
signal applied(profile: Dictionary)
var source: Dictionary={}
var fields: Dictionary={}
var profile_label: Label
func _ready() -> void:
    title="Настройка способности"
    ok_button_text="Сохранить и сбросить бой"
    cancel_button_text="Отмена"
    var body:=VBoxContainer.new()
    add_child(body)
    var hint:=Label.new()
    hint.text="Выбери шаблон и настрой фазы. Электрический прорыв автоматически подстраивает окна эмиссии под длительность фаз; хвосты частиц сохраняются."
    hint.custom_minimum_size.x=360
    hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)
    profile_label=Label.new()
    body.add_child(profile_label)
    var templates:=HBoxContainer.new()
    body.add_child(templates)
    var simple:=Button.new()
    simple.text="Импульсный рывок"
    templates.add_child(simple)
    simple.pressed.connect(func():_populate(A.defaults()))
    var electric:=Button.new()
    electric.text="Электрический прорыв"
    templates.add_child(electric)
    electric.pressed.connect(func():_populate(A.electric_demo()))
    for spec in [["charge","Заряд, с",.05,2,.01],["dash","Рывок, с",.05,2,.01],["contact","Контакт, с",.05,2,.01],["recovery","Восстановление, с",.05,2,.01],["dash_speed","Скорость, px/с",20,260,5],["damage","Урон",1,60,1],["reach","Радиус контакта, px",4,30,1]]:
        var row:=HBoxContainer.new()
        body.add_child(row)
        var label:=Label.new()
        label.text=spec[1]
        label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        row.add_child(label)
        var spin:=SpinBox.new()
        spin.min_value=spec[2]
        spin.max_value=spec[3]
        spin.step=spec[4]
        spin.custom_minimum_size.x=100
        row.add_child(spin)
        fields[spec[0]]=spin
    confirmed.connect(_apply)
func _populate(profile: Dictionary) -> void:
    source=profile.duplicate(true)
    profile_label.text="Шаблон: "+str(source.name)
    for phase in source.phases:fields[phase.id].set_value_no_signal(float(phase.duration))
    for key in ["dash_speed","damage","reach"]:fields[key].set_value_no_signal(float(source[key]))
func open_for(profile: Dictionary) -> void:
    _populate(profile)
    popup_centered(Vector2i(440,400))
func _apply() -> void:
    var result: Dictionary=source.duplicate(true)
    for phase in result.phases:phase.duration=fields[phase.id].value
    for key in ["dash_speed","damage","reach"]:result[key]=fields[key].value
    if A.valid(result):applied.emit(result)
