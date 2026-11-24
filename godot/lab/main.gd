extends Node2D
const UI=preload("res://lab/ui_ru.gd")
## Launcher only. No effect renderer, pool or simulation created until a lab opens.
const VERSION="0.27"
const CAT=preload("res://addons/creature/catalog.gd")
const PREVIEW=preload("res://lab/catalog_preview.gd")
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
var entries:Array=[]
var filtered:Array=[]
var catalog_list:ItemList
var category:OptionButton
var search:LineEdit
var detail_label:Label
var open_button:Button
var copy_button:Button
var viewport:SubViewport
var picture:TextureRect
var preview
var import_dialog:FileDialog
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
    _label(root,"ИНСТРУМЕНТЫ",Vector2(28,96),14,Color("#92c6af"))
    var y:float=122
    for section in SECTIONS:
        for spec in section.items:
            var path:String="res://lab/"+str(spec[3])+".tscn"
            routes[spec[0]]=path
            var button:=Button.new()
            button.position=Vector2(28,y)
            button.size=Vector2(226,43)
            button.text=spec[0]+"  "+spec[1]
            button.alignment=HORIZONTAL_ALIGNMENT_LEFT
            button.tooltip_text=spec[2]
            button.add_theme_stylebox_override("normal",_style(Color("#1e2b39"),Color("#34465a")))
            button.add_theme_stylebox_override("hover",_style(Color("#293b4b"),Color(section.color)))
            root.add_child(button)
            buttons.append(button)
            button.pressed.connect(func():_open(path))
            y+=48
    _label(root,"БИБЛИОТЕКА ШАБЛОНОВ",Vector2(274,96),14,Color("#79b9d4"))
    category=OptionButton.new()
    category.position=Vector2(274,122)
    category.size=Vector2(143,32)
    category.add_item("Все категории")
    for kind in CAT.KINDS:category.add_item(CAT.LABELS[kind])
    root.add_child(category)
    category.item_selected.connect(func(_i:int):_filter())
    search=LineEdit.new()
    search.position=Vector2(423,122)
    search.size=Vector2(190,32)
    search.placeholder_text="Поиск…"
    root.add_child(search)
    search.text_changed.connect(func(_s:String):_filter())
    catalog_list=ItemList.new()
    catalog_list.position=Vector2(274,162)
    catalog_list.size=Vector2(339,278)
    catalog_list.add_theme_constant_override("v_separation",5)
    root.add_child(catalog_list)
    catalog_list.item_selected.connect(_select_entry)
    catalog_list.item_activated.connect(func(_i:int):_open_entry())
    var import_button:=Button.new()
    import_button.text="Импорт JSON"
    import_button.position=Vector2(274,448)
    import_button.size=Vector2(157,32)
    root.add_child(import_button)
    import_button.pressed.connect(func():import_dialog.popup_centered_ratio(.75))
    var refresh:=Button.new()
    refresh.text="Обновить"
    refresh.position=Vector2(439,448)
    refresh.size=Vector2(174,32)
    root.add_child(refresh)
    refresh.pressed.connect(_reload)
    _label(root,"ПРЕДПРОСМОТР",Vector2(632,96),14,Color("#79b9d4"))
    viewport=SubViewport.new()
    viewport.size=Vector2i(240,160)
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    root.add_child(viewport)
    picture=TextureRect.new()
    picture.position=Vector2(632,122)
    picture.size=Vector2(300,200)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    picture.texture=viewport.get_texture()
    picture.hide()
    root.add_child(picture)
    detail_label=_label(root,"Выбери шаблон из списка.",Vector2(632,330),14,Color("#c4d0db"))
    detail_label.size=Vector2(300,103)
    detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    open_button=Button.new()
    open_button.text="Открыть в редакторе"
    open_button.position=Vector2(632,448)
    open_button.size=Vector2(169,32)
    open_button.disabled=true
    root.add_child(open_button)
    open_button.pressed.connect(_open_entry)
    copy_button=Button.new()
    copy_button.text="Копия"
    copy_button.position=Vector2(809,448)
    copy_button.size=Vector2(123,32)
    copy_button.disabled=true
    root.add_child(copy_button)
    copy_button.pressed.connect(_copy_entry)
    import_dialog=FileDialog.new()
    import_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
    import_dialog.access=FileDialog.ACCESS_FILESYSTEM
    import_dialog.filters=PackedStringArray(["*.json ; JSON шаблон"])
    root.add_child(import_dialog)
    import_dialog.file_selected.connect(_import_entry)
    status=_label(root,"Выбор мышью или клавишей. Esc — вернуться в главное меню.",Vector2(28,501),13,Color("#91a5b9"))
    _reload()

func _reload()->void:
    entries=CAT.scan()
    _filter()

func _filter()->void:
    filtered.clear()
    catalog_list.clear()
    var kind:String="" if category.selected<=0 else CAT.KINDS[category.selected-1]
    for e in entries:
        if not CAT.matches(e,kind,search.text):continue
        filtered.append(e)
        var prefix:String="★ " if e.source=="library" else ("● " if e.source=="saved" else "")
        catalog_list.add_item(prefix+e.name+" · "+CAT.LABELS[e.kind])
    _clear_preview()
    status.text="Шаблонов: %d / %d · ★ копия библиотеки · ● сохранённый"%[filtered.size(),entries.size()]

func _clear_preview()->void:
    if is_instance_valid(preview):
        viewport.remove_child(preview)
        preview.queue_free()
        preview=null
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    picture.hide()
    detail_label.text="Выбери шаблон из списка."
    open_button.disabled=true
    copy_button.disabled=true

func _selected_entry()->Dictionary:
    var selected:PackedInt32Array=catalog_list.get_selected_items()
    if selected.is_empty() or selected[0]>=filtered.size():return {}
    return filtered[selected[0]]

func _select_entry(i:int)->void:
    if i<0 or i>=filtered.size():return
    _clear_preview()
    var e:Dictionary=filtered[i]
    preview=PREVIEW.new()
    viewport.add_child(preview)
    preview.set_entry(e)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    picture.show()
    var source:String={"builtin":"Встроенный шаблон","library":"Копия библиотеки","saved":"Сохранённый файл"}.get(e.source,"")
    var detail:String=""
    match e.kind:
        "vfx":detail="%d слоёв"%e.payload.layers.size()
        "animation":detail="%.2f с · %d ключей"%[e.payload.clip.duration,e.payload.clip.keys.size()]
        "ability":detail="%d урона · 4 фазы · постановочный просмотр"%int(e.payload.damage)
        "creature":detail="Хвост: %d · масса ×%.1f · схематичный вид"%[int(e.payload.tail),float(e.payload.mass)]
    detail_label.text=e.name+"\n"+source+"\n"+detail
    open_button.disabled=false
    copy_button.disabled=false

func _open_entry()->void:
    var e:Dictionary=_selected_entry()
    if e.is_empty():return
    get_tree().set_meta(CAT.HANDOFF,e.duplicate(true))
    var err:Error=get_tree().change_scene_to_file("res://lab/"+CAT.ROUTES[e.kind]+".tscn")
    if err!=OK:
        get_tree().remove_meta(CAT.HANDOFF)
        status.text="Ошибка открытия шаблона: "+str(err)

func _copy_entry()->void:
    var e:Dictionary=_selected_entry()
    if e.is_empty():return
    var value:Dictionary=e.duplicate(true)
    value.name=(str(e.name)+" — копия").left(120)
    var saved:Dictionary=CAT.save_copy(value)
    if saved.is_empty():status.text="Не удалось сохранить копию";return
    _reload()
    status.text="Копия сохранена: "+str(saved.name)

func _import_entry(path:String)->void:
    var saved:Dictionary=CAT.import_file(path)
    if saved.is_empty():status.text="Файл не поддерживается или не прошёл проверку";return
    _reload()
    status.text="Импортировано: "+str(saved.name)

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
    draw_line(Vector2(264,92),Vector2(264,480),Color("#34465a"),1)
    draw_line(Vector2(622,92),Vector2(622,480),Color("#34465a"),1)
    draw_line(Vector2(28,485),Vector2(932,485),Color("#34465a"),1)

func _open(path: String) -> void:
    if not ResourceLoader.exists(path):
        status.text="Инструмент недоступен: "+path
        return
    var err: Error=get_tree().change_scene_to_file(path)
    if err!=OK:status.text="Ошибка открытия: "+str(err)

func _unhandled_input(e: InputEvent) -> void:
    if search.has_focus():return
    if e is InputEventKey and e.pressed and not e.echo:
        var key: String=OS.get_keycode_string(UI.physical_key(e))
        if routes.has(key):_open(routes[key])
