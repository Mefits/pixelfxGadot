extends Node2D
const UI=preload("res://lab/ui_ru.gd")
const VERSION="1.0 RC2"
const SECTIONS=[
    {"label":"РАБОЧИЕ ИНСТРУМЕНТЫ","color":"#9dd5b7","items":[
        ["M","Редактор движений Astra","Создание поз, ключей и процедурных целей.","authoring/editor"],
        ["H","Гибридное движение","Просмотр Astra: бег, атаки, ткань, реакции.","hybrid_studio"],
        ["T","Бой","Новый стенд Astra: атака и реакция без ragdoll.","combat_astra"],
        ["P","Box2D · физика попаданий","Отдельный тест импульсов и падений.","motionphysics_studio"],
        ["Y","Настройки эффектов","Слои, кривые, параметры и пресеты VFX.","vfx_workshop"]
    ]},
    {"label":"В РАЗРАБОТКЕ","color":"#b2bac6","items":[
        ["J","Оригинальные анимации PixelFX","Исходные эффекты и постановки PixelFX.","original_catalog"],
        ["U","Старые анимации / VFX","Прежний формат клипов и эффектов.","pose_workshop"],
        ["I","Физика и эволюция","Экспериментальная анатомия и физика.","physics_lab"],
        ["A","Тест атласов","Готовые кадры и тест нагрузки.","atlas_lab"],
        ["L","Молния","Процедурный разряд.","live_lightning"]
    ]}
]
var routes:Dictionary={}
var buttons:Array[Button]=[]
var status:Label
func _ready()->void:
    var layer:=CanvasLayer.new()
    add_child(layer)
    var root:=Control.new()
    root.size=Vector2(960,540)
    layer.add_child(root)
    _label(root,"CREATURE & PIXELFX",Vector2(28,18),27,Color("#e5edf4"))
    _label(root,"LAB "+VERSION+"  /  ИНСТРУМЕНТАРИЙ РАЗРАБОТКИ",Vector2(30,52),13,Color("#91a5b9"))
    var help:=Button.new()
    help.text="Горячие клавиши"
    help.position=Vector2(748,23)
    help.size=Vector2(184,32)
    root.add_child(help)
    help.pressed.connect(_show_help)
    for col in SECTIONS.size():
        var section:Dictionary=SECTIONS[col]
        var x:float=28.+col*464.
        _label(root,section.label,Vector2(x,94),15,Color(section.color))
        for row in section.items.size():
            var spec:Array=section.items[row]
            var path:String="res://lab/"+str(spec[3])+".tscn"
            routes[spec[0]]=path
            var y:float=124.+row*65.
            var button:=Button.new()
            button.position=Vector2(x,y)
            button.size=Vector2(440,58)
            button.tooltip_text=spec[2]
            button.add_theme_stylebox_override("normal",_style(Color("#1e2b39"),Color("#34465a")))
            button.add_theme_stylebox_override("hover",_style(Color("#293b4b"),Color(section.color)))
            root.add_child(button)
            buttons.append(button)
            button.pressed.connect(func():_open(path))
            var name_label:=_label(button,spec[0]+"   "+spec[1],Vector2(13,6),17,Color("#e5edf4"))
            name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
            var desc:=_label(button,spec[2],Vector2(14,32),13,Color("#a4b4c4"))
            desc.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var native_body:bool=ClassDB.class_exists("PixelFXBodyRaster")
    var native_physics:bool=ClassDB.class_exists("MotionPhysics099D")
    var original:bool=ClassDB.class_exists("PixelFXOriginal") and FileAccess.file_exists("res://generated/original_bundle.txt")
    status=_label(root,"Нативные модули:  тело "+("OK" if native_body else "НЕТ")+"  ·  Box2D "+("OK" if native_physics else "НЕТ")+"  ·  PixelFX Original "+("OK" if original else "НЕТ"),Vector2(28,466),13,Color("#9dd5b7") if native_body and native_physics and original else Color("#e4bb85"))
    _label(root,"Выбор мышью или клавишей. Esc — меню. При отсутствии модулей используй полный Windows-пакет.",Vector2(28,501),12,Color("#91a5b9"))
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

func _draw()->void:
    draw_rect(Rect2(0,0,960,540),Color("#111923"))
    draw_rect(Rect2(0,0,960,80),Color("#192634"))
    draw_line(Vector2(480,92),Vector2(480,445),Color("#34465a"),1)
    draw_line(Vector2(28,451),Vector2(932,451),Color("#34465a"),1)

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

func _show_help()->void:
    var dialog:=AcceptDialog.new()
    dialog.title="Горячие клавиши"
    dialog.dialog_text="РЕДАКТОРЫ АНИМАЦИИ И VFX\nSpace — пуск/пауза · Delete — удалить выбранное\nCtrl+S — сохранить · Ctrl+Z — отменить\nCtrl+Y / Ctrl+Shift+Z — повторить\nHome — начало · ←/→ — кадр назад/вперёд\nK — записать ключ · Ctrl+D — дублировать слой VFX\n\nФИЗИКА И БОЙ\nSpace — пауза · W — прыжок · R — сброс\nE — способность · Esc — меню\n\nПростой/расширенный режим запоминается отдельно."
    add_child(dialog)
    dialog.confirmed.connect(dialog.queue_free)
    dialog.canceled.connect(dialog.queue_free)
    dialog.popup_centered(Vector2i(530,300))
