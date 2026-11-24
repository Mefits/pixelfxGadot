extends Node2D
const FX=preload("res://addons/pixelfx/effects/chain_lightning.gd")
const RUN=preload("res://addons/pixelfx/native/runtime.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const ACTOR=preload("res://addons/pixelfx/native/actor.gd")
var fx
var surface
var actor: Dictionary=ACTOR.stock(2)
var cpp: bool=true
var clock: float=0.0
var pause_time: float=0.0
var label: Label
func _ready() -> void:
    surface=SURFACE.new()
    add_child(surface)
    surface.configure(248,104)
    surface.position=Vector2(108,114)
    surface.scale=Vector2.ONE*3
    label=Label.new()
    label.position=Vector2(24,20)
    add_child(label)
    _restart()
func _restart() -> void:
    fx=RUN.new(FX.META,func(o): return FX.new(o),{"x":40,"y":82})
    cpp=fx.impl.enable_acceleration(cpp)
    pause_time=0.0
    clock=0.0
func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#121824"))
    draw_rect(Rect2(108,360,744,66),Color("#293547"))
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE: get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_SPACE: _restart()
            KEY_A: cpp=fx.impl.enable_acceleration(not cpp)
func _process(delta: float) -> void:
    clock+=delta
    if clock<1.0/30:
        return
    clock=fmod(clock,1.0/30)
    if fx.done():
        pause_time+=1.0/30
        if pause_time>.6:
            _restart()
        return
    var p=surface.painter
    p.clear()
    var start: int=Time.get_ticks_usec()
    fx.draw(p,"back")
    p.reset()
    for x in [40,98,144,190]:
        p.place(x,82)
        ACTOR.draw_stock(p,actor)
    fx.draw(p,"front")
    surface.present()
    label.text="CHAIN LIGHTNING / native effect + static original actors | %s | %.2f ms | A / Space / Esc"%["C++" if cpp else "GDScript",(Time.get_ticks_usec()-start)/1000.0]
    fx.update(1.0/30)
