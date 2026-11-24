extends ConfirmationDialog
const Q=preload("res://addons/pixelfx/composer/quick_adjust.gd")
signal applied(preset: Dictionary)
var source: Dictionary={}
var fields: Dictionary={}
func _ready() -> void:
    title="Быстрая настройка эффекта"
    ok_button_text="Применить"
    cancel_button_text="Отмена"
    var body:=VBoxContainer.new()
    add_child(body)
    var hint:=Label.new()
    hint.text="Настрой эффект целиком. Исходная структура и кривые сохраняются; значения ограничены допустимым диапазоном."
    hint.custom_minimum_size.x=330
    hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)
    for spec in [["size","Размер ×",.25,2,.05,1.0],["power","Интенсивность ×",.25,2,.05,1.0],["time","Длительность ×",.5,2,.05,1.0],["hue","Оттенок, °",-180,180,5,0.0]]:
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
        spin.value=spec[5]
        spin.custom_minimum_size.x=100
        row.add_child(spin)
        fields[spec[0]]=spin
    confirmed.connect(_apply)
func open_for(preset: Dictionary) -> void:
    source=preset.duplicate(true)
    for key in fields:
        fields[key].set_value_no_signal(0.0 if key=="hue" else 1.0)
    popup_centered(Vector2i(360,230))
func _apply() -> void:
    var result: Dictionary=Q.scaled(source,fields.size.value,fields.power.value,fields.time.value,fields.hue.value)
    if not result.is_empty():applied.emit(result)
