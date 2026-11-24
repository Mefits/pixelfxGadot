extends Node2D
const UI=preload("res://lab/ui_ru.gd")
## Launcher only. No effect renderer, pool or simulation created until a lab opens.
const VERSION="0.22"
const SECTIONS=[
    {"label":"СПЕЦЭФФЕКТЫ","color":"#79b9d4","items":[
        ["Y","Конструктор эффектов","Слои, кривые параметров и свои пресеты.","vfx_workshop"],
        ["J","Каталог PixelFX","Оригинальные эффекты и постановки.","original_catalog"],
        ["A","Тест атласов","Готовые кадры и тест нагрузки.","atlas_lab"],
        ["L","Молния","Процедурный разряд в реальном времени.","live_lightning"]
    ]},
    {"label":"АНИМАЦИЯ И СУЩЕСТВА","color":"#92c6af","items":[
        ["U","Редактор анимаций","Позы скелета и ключевые кадры.","pose_workshop"],
        ["T","Боевая лаборатория","Два бойца и проверка атак.","combat_lab"],
        ["I","Физика и эволюция","Физика, атаки, изменение анатомии.","physics_lab"]
    ]}
]
var routes: Dictionary={}
var buttons: Array[Button]=[]
var status: Label
func _ready() -> void:
    var layer:=CanvasLayer.new()
    add_child(layer)
    var theme0:=Theme.new()
    theme0.default_font_size=14
    var root:=Control.new()
    root.theme=theme0
    root.size=Vector2(960,540)
    layer.add_child(root)
    _label(root,"CREATURE & PIXELFX",Vector2(28,20),28,Color("#e5edf4"))
    _label(root,"ИНСТРУМЕНТАРИЙ РАЗРАБОТКИ    /    "+VERSION,Vector2(30,56),13,Color("#91a5b9"))
    _label(root,"Выбери рабочее пространство",Vector2(30,92),16,Color("#c4d0db"))
    for i in range(SECTIONS.size()):
        var section: Dictionary=SECTIONS[i]
        var x: float=28+float(i)*462
        _label(root,section.label,Vector2(x,130),13,Color(section.color))
        for j in range(section.items.size()):
            var spec: Array=section.items[j]
            var path: String="res://lab/"+str(spec[3])+".tscn"
            routes[spec[0]]=path
            var button:=Button.new()
            button.position=Vector2(x,156+j*77)
            button.size=Vector2(440,68)
            button.text=""
            button.tooltip_text=spec[2]
            button.add_theme_stylebox_override("normal",_style(Color("#1e2b39"),Color("#34465a")))
            button.add_theme_stylebox_override("hover",_style(Color("#293b4b"),Color(section.color)))
            button.add_theme_stylebox_override("pressed",_style(Color("#354b5b"),Color(section.color)))
            root.add_child(button)
            buttons.append(button)
            button.pressed.connect(func():_open(path))
            var name_label: Label=_label(button,spec[1],Vector2(16,8),18,Color("#e3ebf1"))
            name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
            var key_label: Label=_label(button,spec[0],Vector2(408,9),13,Color(section.color))
            key_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
            var detail: Label=_label(button,spec[2],Vector2(16,35),14,Color("#a2b5c5"))
            detail.size=Vector2(402,30)
            detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
            detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
    status=_label(root,"Выбор мышью или клавишей. Esc — вернуться в главное меню.",Vector2(28,501),13,Color("#91a5b9"))

func _label(parent: Control,value: String,at: Vector2,font_size: int,color: Color) -> Label:
    var l:=Label.new()
    l.position=at
    l.text=value
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",color)
    parent.add_child(l)
    return l

func _style(bg: Color,border: Color) -> StyleBoxFlat:
    var s:=StyleBoxFlat.new()
    s.bg_color=bg
    s.border_color=border
    s.set_border_width_all(1)
    s.set_corner_radius_all(5)
    return s

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#111923"))
    draw_rect(Rect2(0,0,960,81),Color("#192634"))
    draw_line(Vector2(28,119),Vector2(932,119),Color("#34465a"),1)
    draw_line(Vector2(28,485),Vector2(932,485),Color("#34465a"),1)

func _open(path: String) -> void:
    if not ResourceLoader.exists(path):
        status.text="Инструмент недоступен: "+path
        return
    var err: Error=get_tree().change_scene_to_file(path)
    if err!=OK:status.text="Ошибка открытия: "+str(err)

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        var key: String=OS.get_keycode_string(UI.physical_key(e))
        if routes.has(key):_open(routes[key])
