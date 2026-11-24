extends Node2D
const FX=preload("res://addons/pixelfx/effects/electrified.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const A=preload("res://addons/pixelfx/native/actor.gd")
var actor: Dictionary=A.stock(2)
var fx=FX.new({"actor":actor})
var surface
var cpp: bool=true
var t: float=0
var last: int=-1
var label: Label
func _ready() -> void:
    surface=SURFACE.new()
    add_child(surface)
    surface.configure(108,92)
    surface.position=Vector2(264,100)
    surface.scale=Vector2.ONE*4
    surface.painter.place(54,76)
    cpp=fx.enable_acceleration()
    label=Label.new()
    label.position=Vector2(24,20)
    add_child(label)
func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#121824"))
    draw_rect(Rect2(264,404,432,64),Color("#293547"))
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE: get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_A: cpp=fx.enable_acceleration(not cpp)
            KEY_1,KEY_2:
                actor=A.stock(1 if event.keycode==KEY_1 else 2)
                fx.set_actor(actor)
                last=-1
func _process(delta: float) -> void:
    t=fmod(t+delta,2)
    var f: int=int(floor(t*30))
    if f==last:
        return
    last=f
    var p=surface.painter
    p.clear()
    var start: int=Time.get_ticks_usec()
    fx.draw_back(p,float(f)/30)
    A.draw_stock(p,actor)
    fx.draw(p,float(f)/30)
    surface.present()
    label.text="ELECTRIFIED / native silhouette | 1/2 actor size | A backend | %.2f ms | %s | ESC"%[(Time.get_ticks_usec()-start)/1000.0,"C++" if cpp else "GDScript"]
