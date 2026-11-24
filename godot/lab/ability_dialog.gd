extends ConfirmationDialog
const A=preload("res://addons/creature/ability.gd")
signal applied(profile: Dictionary)
var source: Dictionary={}
var fields: Dictionary={}
func _ready() -> void:
    title="Настройка способности"
    ok_button_text="Сохранить и сбросить бой"
    cancel_button_text="Отмена"
    var body:=VBoxContainer.new()
    add_child(body)
    var hint:=Label.new()
    hint.text="Импульсный рывок: четыре фазы. Визуальные пресеты и позы остаются в профиле. Длительность эффектов пока не масштабируется автоматически."
    hint.custom_minimum_size.x=360
    hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)
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
    var reset:=Button.new()
    reset.text="Исходный шаблон"
    body.add_child(reset)
    reset.pressed.connect(func():_populate(A.defaults()))
    confirmed.connect(_apply)
func _populate(profile: Dictionary) -> void:
    source=profile.duplicate(true)
    for phase in source.phases:fields[phase.id].set_value_no_signal(float(phase.duration))
    for key in ["dash_speed","damage","reach"]:fields[key].set_value_no_signal(float(source[key]))
func open_for(profile: Dictionary) -> void:
    _populate(profile)
    popup_centered(Vector2i(390,370))
func _apply() -> void:
    var result: Dictionary=source.duplicate(true)
    for phase in result.phases:phase.duration=fields[phase.id].value
    for key in ["dash_speed","damage","reach"]:result[key]=fields[key].value
    if A.valid(result):applied.emit(result)
