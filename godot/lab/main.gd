extends Node2D
const UI=preload("res://lab/ui_ru.gd")
## Launcher only. No effect renderer, pool or simulation created until a lab opens.
const VERSION="0.38"
const VIEW=preload("res://lab/library_view.gd")
var view_state=VIEW.new()
var scope:OptionButton
var favorite_button:Button
var rename_button:Button
var trash_button:Button
var rename_dialog:ConfirmationDialog
var rename_edit:LineEdit
var trash_dialog:ConfirmationDialog
var pending_id:String=""
const EXP=preload("res://addons/creature/kit_export.gd")
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
var export_dialog:FileDialog
var export_button:Button
var pending_export:Dictionary={}
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
    var help:=Button.new()
    help.text="Горячие клавиши"
    help.position=Vector2(748,26)
    help.size=Vector2(184,32)
    root.add_child(help)
    help.pressed.connect(_show_help)
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
    view_state.load_state()
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
    scope=OptionButton.new()
    scope.position=Vector2(274,160)
    scope.size=Vector2(339,30)
    for value in ["Все шаблоны","Мои шаблоны","Избранное","Недавние","Корзина"]:scope.add_item(value)
    root.add_child(scope)
    scope.item_selected.connect(func(_i:int):_filter())
    catalog_list=ItemList.new()
    catalog_list.position=Vector2(274,196)
    catalog_list.size=Vector2(339,244)
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
    picture.size=Vector2(270,180)
    picture.position=Vector2(647,122)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    picture.texture=viewport.get_texture()
    picture.hide()
    root.add_child(picture)
    detail_label=_label(root,"Выбери шаблон из списка.",Vector2(632,306),14,Color("#c4d0db"))
    detail_label.size=Vector2(300,64)
    detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    detail_label.clip_text=true
    _management(root)
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
    export_button=Button.new()
    export_button.text="Экспорт в игру (ZIP)"
    export_button.position=Vector2(632,412)
    export_button.size=Vector2(300,30)
    export_button.disabled=true
    root.add_child(export_button)
    export_button.pressed.connect(_begin_export)
    export_dialog=FileDialog.new()
    export_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
    export_dialog.access=FileDialog.ACCESS_FILESYSTEM
    export_dialog.filters=PackedStringArray(["*.zip ; Godot runtime package"])
    root.add_child(export_dialog)
    export_dialog.file_selected.connect(_export_entry)
    export_dialog.canceled.connect(func():pending_export.clear())
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
    var ordered:Array=CAT.scan_trash() if scope.selected==4 else entries.duplicate()
    if scope.selected==3:
        ordered.sort_custom(func(a:Dictionary,b:Dictionary):return view_state.recent.find(a.id)<view_state.recent.find(b.id))
    for e in ordered:
        if not view_state.includes(e,scope.selected) or not CAT.matches(e,kind,search.text):continue
        filtered.append(e)
        var prefix:String="★ " if e.source=="library" else ("● " if e.source=="saved" else "")
        var star:String="☆ " if e.id in view_state.favorites else ""
        catalog_list.add_item(star+prefix+e.name+" · "+CAT.LABELS[e.kind])
    _clear_preview()
    status.text="В корзине: %d · выбери копию и нажми «Восстановить»"%filtered.size() if scope.selected==4 else "Шаблонов: %d / %d · ☆ избранное · ★ копия · ● сохранённый"%[filtered.size(),entries.size()]

func _clear_preview()->void:
    if is_instance_valid(preview):
        viewport.remove_child(preview)
        preview.queue_free()
        preview=null
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    picture.hide()
    detail_label.text="Выбери шаблон из списка."
    open_button.disabled=true
    open_button.text="Открыть в редакторе"
    copy_button.disabled=true
    export_button.disabled=true
    favorite_button.disabled=true
    rename_button.disabled=true
    trash_button.disabled=true

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
    var source:String={"builtin":"Встроенный шаблон","library":"Копия библиотеки","saved":"Сохранённый файл","trash":"В корзине"}.get(e.source,"")
    var detail:String=""
    match e.kind:
        "vfx":detail="%d слоёв"%e.payload.layers.size()
        "animation":detail="%.2f с · %d ключей"%[e.payload.clip.duration,e.payload.clip.keys.size()]
        "ability":
            if e.payload.get("engine","")=="physical":detail="Физическая способность · %.2f с · %d урона"%[e.payload.duration,int(e.payload.damage)]
            else:detail="%d урона · 4 фазы · постановочный просмотр"%int(e.payload.damage)
        "creature":detail="Лап: %d · хвост: %d · щупалец: %d"%[int(e.payload.get("leg_count",4)) if e.payload.limbs else 0,int(e.payload.tail),int(e.payload.get("tentacles",0))]
    detail_label.text=e.name+"\n"+source+"\n"+detail
    open_button.disabled=false
    copy_button.disabled=false
    favorite_button.disabled=false
    favorite_button.text="★ Убрать" if e.id in view_state.favorites else "☆ Избранное"
    rename_button.disabled=e.source!="library"
    trash_button.disabled=e.source!="library"
    export_button.disabled=not EXP.available()
    if not EXP.available():export_button.tooltip_text="Runtime ZIP не включён. Используй полный проверенный пакет."
    if e.source=="trash":
        open_button.text="Восстановить"
        copy_button.disabled=true
        export_button.disabled=true
        favorite_button.disabled=true

func _open_entry()->void:
    var e:Dictionary=_selected_entry()
    if e.is_empty():return
    if e.source=="trash":
        var restored:Error=CAT.restore_copy(e.id)
        if restored!=OK:status.text="Ошибка восстановления: "+error_string(restored);return
        _show_saved(e.id)
        status.text="Копия восстановлена: "+e.name
        return
    get_tree().set_meta(CAT.HANDOFF,e.duplicate(true))
    var err:Error=get_tree().change_scene_to_file("res://lab/"+CAT.route(e)+".tscn")
    if err!=OK:
        get_tree().remove_meta(CAT.HANDOFF)
        status.text="Ошибка открытия шаблона: "+str(err)
    else:view_state.opened(e.id)

func _copy_entry()->void:
    var e:Dictionary=_selected_entry()
    if e.is_empty() or e.source=="trash":return
    var value:Dictionary=e.duplicate(true)
    value.name=(str(e.name)+" — копия").left(120)
    if e.kind in ["vfx","ability","creature"]:value.payload.name=value.name
    var saved:Dictionary=CAT.save_copy(value)
    if saved.is_empty():status.text="Не удалось сохранить копию";return
    _show_saved(saved.id)
    status.text="Копия сохранена: "+str(saved.name)

func _begin_export()->void:
    pending_export=_selected_entry().duplicate(true)
    if pending_export.is_empty() or pending_export.source=="trash":return
    export_dialog.current_file="creature_template_"+str(int(Time.get_unix_time_from_system()))+".zip"
    export_dialog.popup_centered_ratio(.75)

func _export_entry(path:String)->void:
    if pending_export.is_empty():return
    var err:Error=EXP.export_entry(pending_export,path)
    pending_export.clear()
    if err==OK:status.text="ZIP сохранён: "+path.get_file()
    elif err==ERR_ALREADY_EXISTS:status.text="Файл уже существует. Выбери новое имя."
    else:status.text="Ошибка экспорта: "+error_string(err)

func _import_entry(path:String)->void:
    var saved:Dictionary=CAT.import_file(path)
    if saved.is_empty():status.text="Файл не поддерживается или не прошёл проверку";return
    _show_saved(saved.id)
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
    if not UI.editor_shortcut(self,e):return
    if e.ctrl_pressed and UI.physical_key(e)==KEY_F:
        search.grab_focus()
        get_viewport().set_input_as_handled()
        return
    if e.ctrl_pressed:return
    if UI.physical_key(e)==KEY_F2:_begin_rename();return
    if UI.physical_key(e)==KEY_DELETE:_begin_trash();return
    var key:String=OS.get_keycode_string(UI.physical_key(e))
    if routes.has(key):_open(routes[key])

func _show_help()->void:
    var dialog:=AcceptDialog.new()
    dialog.title="Горячие клавиши"
    dialog.dialog_text="РЕДАКТОРЫ АНИМАЦИИ И VFX\nSpace — пуск/пауза · Delete — удалить выбранное\nCtrl+S — сохранить · Ctrl+Z — отменить\nCtrl+Y / Ctrl+Shift+Z — повторить\nHome — начало · ←/→ — кадр назад/вперёд\nK — записать ключ · Ctrl+D — дублировать слой VFX\n\nФИЗИКА И БОЙ\nSpace — пауза · W — прыжок · R — сброс\nE — способность · Esc — меню\n\nПростой/расширенный режим запоминается отдельно."
    add_child(dialog)
    dialog.confirmed.connect(dialog.queue_free)
    dialog.canceled.connect(dialog.queue_free)
    dialog.popup_centered(Vector2i(530,300))

func _management(root:Control)->void:
    favorite_button=Button.new()
    favorite_button.text="☆ Избранное"
    favorite_button.position=Vector2(632,376)
    favorite_button.size=Vector2(112,30)
    root.add_child(favorite_button)
    favorite_button.pressed.connect(_favorite)
    rename_button=Button.new()
    rename_button.text="Имя"
    rename_button.position=Vector2(750,376)
    rename_button.size=Vector2(80,30)
    rename_button.tooltip_text="Переименовать копию (F2)"
    root.add_child(rename_button)
    rename_button.pressed.connect(_begin_rename)
    trash_button=Button.new()
    trash_button.text="В корзину"
    trash_button.position=Vector2(836,376)
    trash_button.size=Vector2(96,30)
    trash_button.tooltip_text="Переместить копию в корзину (Delete)"
    root.add_child(trash_button)
    trash_button.pressed.connect(_begin_trash)
    rename_dialog=ConfirmationDialog.new()
    rename_dialog.title="Переименовать шаблон"
    rename_dialog.ok_button_text="Сохранить имя"
    rename_edit=LineEdit.new()
    rename_edit.max_length=120
    rename_dialog.add_child(rename_edit)
    root.add_child(rename_dialog)
    rename_dialog.confirmed.connect(_rename_confirmed)
    trash_dialog=ConfirmationDialog.new()
    trash_dialog.title="Переместить копию в корзину?"
    trash_dialog.ok_button_text="В корзину"
    root.add_child(trash_dialog)
    trash_dialog.confirmed.connect(_trash_confirmed)
func _select_id(id:String)->void:
    for i in range(filtered.size()):
        if filtered[i].id==id:
            catalog_list.select(i)
            catalog_list.ensure_current_is_visible()
            _select_entry(i)
            return
func _show_saved(id:String)->void:
    search.text=""
    scope.select(1)
    category.select(0)
    _reload()
    _select_id(id)
func _favorite()->void:
    var e:Dictionary=_selected_entry()
    if e.is_empty() or e.source=="trash":return
    view_state.toggle(e.id)
    _filter()
    _select_id(e.id)
func _begin_rename()->void:
    var e:Dictionary=_selected_entry()
    if e.get("source")!="library":return
    pending_id=e.id
    rename_edit.text=e.name
    rename_dialog.popup_centered(Vector2i(420,100))
    rename_edit.grab_focus()
    rename_edit.select_all()
func _rename_confirmed()->void:
    var saved:Dictionary=CAT.rename_copy(pending_id,rename_edit.text)
    pending_id=""
    if saved.is_empty():status.text="Не удалось переименовать. Проверь имя.";return
    _show_saved(saved.id)
    status.text="Имя сохранено: "+saved.name
func _begin_trash()->void:
    var e:Dictionary=_selected_entry()
    if e.get("source")!="library":return
    pending_id=e.id
    trash_dialog.dialog_text="«"+e.name+"» будет перемещён в папку creature_library_trash. Исходные шаблоны не меняются."
    trash_dialog.popup_centered(Vector2i(440,140))
func _trash_confirmed()->void:
    var id:String=pending_id
    pending_id=""
    var err:Error=CAT.trash_copy(id)
    if err!=OK:status.text="Не удалось переместить: "+error_string(err);return
    view_state.remove(id)
    _reload()
    status.text="Копия в корзине. Можно восстановить через фильтр «Корзина»."
