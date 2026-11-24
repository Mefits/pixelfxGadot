extends Node2D
const FX=preload("res://addons/pixelfx/effects/custom/rift_collapse.gd")
const PLAYER=preload("res://addons/pixelfx/native/effect_player.gd")
const NAMES=["Violet fracture","Ion implosion","Solar shear"]
var fx
var player
var label: Label
var preset: int=0
var seed_value: int=121
var cpp: bool=true
var bright: bool=false
var gap: float=0.0
var auto_repeat: bool=true
var slider: HSlider
var adjusting: bool=false

func _ready() -> void:
    player=PLAYER.new()
    add_child(player)
    player.position=Vector2(480,296)
    player.scale=Vector2.ONE*3
    player.finished.connect(_finished)
    var layer:=CanvasLayer.new()
    add_child(layer)
    var title:=Label.new()
    title.position=Vector2(24,16)
    title.text="ORIGINAL WORKSHOP / RIFT COLLAPSE"
    title.add_theme_font_size_override("font_size",22)
    layer.add_child(title)
    var help:=Label.new()
    help.position=Vector2(24,50)
    help.text="1/2/3: direction | Space: replay | P: pause | A: backend | B: background | N: seed | Esc: back"
    layer.add_child(help)
    label=Label.new()
    label.position=Vector2(24,78)
    layer.add_child(label)
    slider=HSlider.new()
    slider.position=Vector2(192,508)
    slider.size=Vector2(576,22)
    slider.max_value=FX.DURATION
    slider.step=1.0/30.0
    slider.value_changed.connect(_scrub)
    layer.add_child(slider)
    _select()

func _select() -> void:
    fx=FX.new(seed_value,preset)
    cpp=fx.enable_acceleration(cpp)
    player.prepare(fx,FX.SIZE,FX.PIVOT,FX.DURATION,FX.FPS)
    auto_repeat=true
    player.play()

func _finished() -> void:
    gap=0.55

func _scrub(v: float) -> void:
    if adjusting:
        return
    auto_repeat=false
    player.pause()
    player.seek(v)

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#aaa99d") if bright else Color("#111826"))
    draw_rect(Rect2(192,104,576,384),Color("#c8c7bb") if bright else Color("#192538"))
    draw_line(Vector2(192,488),Vector2(768,488),Color("#59677b"))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1,KEY_2,KEY_3:
                preset=event.keycode-KEY_1
                _select()
            KEY_SPACE:
                auto_repeat=true
                player.play()
            KEY_P:
                auto_repeat=false
                if player.playing:
                    player.pause()
                else:
                    player.play(false)
            KEY_A:
                cpp=fx.enable_acceleration(not cpp)
                player.seek(player.time)
            KEY_N:
                seed_value+=1
                _select()
            KEY_B:
                bright=not bright
                queue_redraw()
            KEY_ESCAPE:
                get_tree().change_scene_to_file("res://lab/main.tscn")

func _process(delta: float) -> void:
    if auto_repeat and not player.playing:
        gap-=delta
        if gap<=0.0:
            player.play()
    adjusting=true
    slider.value=player.time
    adjusting=false
    label.text="%s | %s | %.2f ms update | %.2f s | seed %d" % [NAMES[preset],"C++" if cpp else "GDScript",player.update_ms,player.time,seed_value]
