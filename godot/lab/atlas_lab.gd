extends Node2D
const UI=preload("res://lab/ui_ru.gd")
const CLIP = preload("res://addons/pixelfx/clip.gd")
const PLAYER = preload("res://addons/pixelfx/player.gd")
const POOL_SIZE: int = 32
var paths: Array[String] = []
var clips: Dictionary = {}
var pool: Array = []
var cursor: int = 0
var selected: int = 0
var status: Label
var perf: Label
var menu: OptionButton
var bright: bool = false
var mirrored: bool = false
var samples: Array[float] = []
var clock: float = 0.0

func _ready() -> void:
    var folder := DirAccess.open("res://generated")
    if folder != null:
        var dirs := folder.get_directories()
        dirs.sort()
        for name in dirs:
            var path: String = "res://generated/" + name + "/clip.json"
            if FileAccess.file_exists(path):
                paths.append(path)
    for i in range(POOL_SIZE):
        var p = PLAYER.new()
        add_child(p)
        pool.append(p)
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    var heading := Label.new()
    heading.position = Vector2(24, 14)
    heading.text = "PIXELFX / АТЛАСЫ И ТЕСТ НАГРУЗКИ"
    heading.add_theme_font_size_override("font_size", 22)
    layer.add_child(heading)
    menu = OptionButton.new()
    menu.position = Vector2(24, 52)
    menu.size = Vector2(310, 35)
    for path in paths:
        menu.add_item(path.get_base_dir().get_file())
    menu.item_selected.connect(_select)
    layer.add_child(menu)
    status = Label.new()
    status.position = Vector2(24, 98)
    status.text = "ЛКМ эффект · B фон · M зеркало · пробел нагрузка · C очистить · Esc меню"
    if paths.is_empty():
        status.text = "Запусти setup_windows.bat для экспорта эффектов, затем открой Godot."
    layer.add_child(status)
    perf = Label.new()
    perf.position = Vector2(24, 124)
    layer.add_child(perf)
    for spec in [["Pose Workshop", "res://lab/pose_workshop.tscn"],["Combat Lab","res://lab/combat_lab.tscn"]]:
        var b:=Button.new()
        b.text="Анимации" if spec[0]=="Pose Workshop" else "Бой"
        b.position=Vector2(640 if spec[0]=="Pose Workshop" else 795,52)
        b.size=Vector2(145,35)
        layer.add_child(b)
        var dest: String=spec[1]
        b.pressed.connect(func():get_tree().change_scene_to_file(dest))
    var physics_button:=Button.new()
    physics_button.text="Физика (I)"
    physics_button.position=Vector2(480,52)
    physics_button.size=Vector2(150,35)
    layer.add_child(physics_button)
    physics_button.pressed.connect(func():get_tree().change_scene_to_file("res://lab/physics_lab.tscn"))
    var vfx_button:=Button.new()
    vfx_button.text="Эффекты (Y)"
    vfx_button.position=Vector2(480,14)
    vfx_button.size=Vector2(180,30)
    layer.add_child(vfx_button)
    vfx_button.pressed.connect(func():get_tree().change_scene_to_file("res://lab/vfx_workshop.tscn"))
    if not paths.is_empty():
        _select(0)

func _select(i: int) -> void:
    selected = i
    # Explicit load on selection, never during the cast. Keep only selected clip
    # and any clips referenced by active/reusable players.
    for p in pool:
        p.stop()
        p.clip = null
        p.color_sprite.texture = null
        p.light_sprite.texture = null
    clips.clear()
    var clip = CLIP.read_clip(paths[i])
    if clip != null:
        clips[i] = clip
        status.text = "ЛКМ эффект · пробел нагрузка · C очистить · B фон · M зеркало · Esc меню"
    else:
        status.text = "Не удалось загрузить атлас."

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540), Color("#aaa99d") if bright else Color("#121824"))
    draw_rect(Rect2(0,420,960,120), Color("#85877e") if bright else Color("#232b39"))
    draw_line(Vector2(0,420), Vector2(960,420), Color("#575c66"), 2)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _play(get_global_mouse_position())
    if event is InputEventKey and event.pressed and not event.echo:
        if UI.physical_key(event) == KEY_ESCAPE:
            get_tree().change_scene_to_file("res://lab/main.tscn")
        elif UI.physical_key(event) == KEY_B:
            bright = not bright
            queue_redraw()
        elif UI.physical_key(event) == KEY_M:
            mirrored = not mirrored
        elif UI.physical_key(event) == KEY_Y:
            get_tree().change_scene_to_file("res://lab/vfx_workshop.tscn")
        elif UI.physical_key(event) == KEY_I:
            get_tree().change_scene_to_file("res://lab/physics_lab.tscn")
        elif UI.physical_key(event) == KEY_U:
            get_tree().change_scene_to_file("res://lab/pose_workshop.tscn")
        elif UI.physical_key(event) == KEY_T:
            get_tree().change_scene_to_file("res://lab/combat_lab.tscn")
        elif UI.physical_key(event) == KEY_J:
            get_tree().change_scene_to_file("res://lab/original_catalog.tscn")
        elif UI.physical_key(event) == KEY_E:
            get_tree().change_scene_to_file("res://lab/electrified.tscn")
        elif UI.physical_key(event) == KEY_H:
            get_tree().change_scene_to_file("res://lab/chain_lightning.tscn")
        elif UI.physical_key(event) == KEY_K:
            get_tree().change_scene_to_file("res://lab/custom_effects.tscn")
        elif UI.physical_key(event) == KEY_O:
            get_tree().change_scene_to_file("res://lab/ball_lightning.tscn")
        elif UI.physical_key(event) == KEY_L:
            get_tree().change_scene_to_file("res://lab/live_lightning.tscn")
        elif UI.physical_key(event) == KEY_C:
            for p in pool:
                p.stop()
        elif UI.physical_key(event) == KEY_SPACE:
            for i in range(POOL_SIZE):
                _play(Vector2(60 + (i % 8) * 120, 205 + int(i / 8) * 82))

func _play(at: Vector2) -> void:
    if not clips.has(selected):
        return
    var p = pool[cursor]
    cursor = (cursor + 1) % POOL_SIZE
    p.play_clip(clips[selected], at, -1 if mirrored else 1, 2.0)

func _process(delta: float) -> void:
    samples.append(delta * 1000.0)
    clock += delta
    if clock >= 1.0:
        samples.sort()
        var n: int = samples.size()
        var active: int = 0
        for p in pool:
            if p.active:
                active += 1
        perf.text = "FPS %d | p95 %.2f | p99 %.2f | макс. %.2f мс | активны %d/%d" % [Engine.get_frames_per_second(), samples[clampi(int(ceil(n * 0.95)) - 1,0,n-1)], samples[clampi(int(ceil(n * 0.99)) - 1,0,n-1)], samples[n-1],active,POOL_SIZE]
        samples.clear()
        clock = 0.0
