extends RefCounted
## Display names only. Stable English identifiers stay in saved data.
const LABELS={
    "vfx": "Спецэффект",
    "idle": "Стойка",
    "walk": "Ходьба",
    "jump": "Прыжок",
    "strike": "Удар",
    "cross": "Удар другой рукой",
    "heavy": "Тяжёлый удар",
    "kick": "Удар ногой",
    "air_strike": "Удар в воздухе",
    "hurt_heavy": "Тяжёлое попадание",
    "cast": "Магия",
    "guard": "Блок",
    "hurt": "Получение урона",
    "charge": "Заряд",
    "hips": "Таз",
    "chest": "Грудь",
    "head": "Голова",
    "shoulder_far": "Плечо (дальнее)",
    "shoulder_near": "Плечо (ближнее)",
    "elbow_far": "Локоть (дальний)",
    "elbow_near": "Локоть (ближний)",
    "hand_far": "Кисть (дальняя)",
    "hand_near": "Кисть (ближняя)",
    "thigh_far": "Бедро (дальнее)",
    "thigh_near": "Бедро (ближнее)",
    "knee_far": "Колено (дальнее)",
    "knee_near": "Колено (ближнее)",
    "foot_far": "Стопа (дальняя)",
    "foot_near": "Стопа (ближняя)",
    "lightning": "Молния",
    "sparks": "Искры",
    "glow": "Свечение",
    "ring": "Кольцо",
    "slash": "Дуга удара",
    "droplets": "Капли",
    "smoke": "Дым",
    "trail": "Шлейф",
    "tendril": "Щупальца",
    "organic_mass": "Живая масса",
    "shockwave": "Ударная волна",
    "beam": "Энергетический луч",
    "vortex": "Вихрь",
    "orb": "Энергетическая сфера",
    "rift": "Разлом",
    "origin": "Центр",
    "hand": "Рука",
    "target": "Цель",
    "linear": "Линейная",
    "ease in": "Разгон",
    "ease out": "Торможение",
    "smooth": "Плавная",
    "windup": "замах",
    "recover": "возврат",
    "Electric burst": "Электроразряд",
    "Acid impact": "Кислота",
    "Claw slash": "Удар когтем",
    "Fire burst": "Вспышка огня"
}
static func label(id: String) -> String:
    return LABELS.get(id,id)
static func physical_key(e: InputEventKey) -> Key:
    return e.physical_keycode if e.physical_keycode!=0 else e.keycode

## Shared editor preferences and shortcut protection.
const PREFS="user://creature_editor_ui.cfg"
static func advanced(editor:String)->bool:
    var cfg:=ConfigFile.new()
    cfg.load(PREFS)
    return bool(cfg.get_value("mode",editor,false))
static func set_advanced(editor:String,value:bool)->void:
    var cfg:=ConfigFile.new()
    cfg.load(PREFS)
    cfg.set_value("mode",editor,value)
    cfg.save(PREFS)
static func _popup_open(node:Node)->bool:
    for child in node.get_children():
        if child is Window:
            if child.visible:return true
        elif not child is SubViewport and _popup_open(child):return true
    return false
static func editor_shortcut(owner:Node,e:InputEvent)->bool:
    if not e is InputEventKey or not e.pressed or e.echo or e.alt_pressed:return false
    if _popup_open(owner):return false
    var focus:Control=owner.get_viewport().gui_get_focus_owner()
    return not (focus is LineEdit or focus is TextEdit)
static func action_button(b:Button,hint:String,primary:bool=false)->void:
    b.tooltip_text=hint
    b.custom_minimum_size.y=30
    if primary:
        var style:=StyleBoxFlat.new()
        style.bg_color=Color("#27506a")
        style.set_corner_radius_all(4)
        style.set_content_margin_all(5)
        b.add_theme_stylebox_override("normal",style)
        var hover:=style.duplicate()
        hover.bg_color=Color("#356b88")
        b.add_theme_stylebox_override("hover",hover)
