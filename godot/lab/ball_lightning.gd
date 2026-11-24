extends Node2D
const UI=preload("res://lab/ui_ru.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const FX=preload("res://addons/pixelfx/effects/ball_lightning.gd")
var fx=FX.new()
var surface
var label: Label
var time: float=0.0
var shown_frame: int=-1
var cpp: bool=false

func _ready() -> void:
    surface=SURFACE.new()
    add_child(surface)
    surface.position=Vector2(208,100)
    surface.scale=Vector2.ONE*4
    surface.configure(FX.SIZE.x,FX.SIZE.y)
    surface.painter.place(FX.PIVOT.x,FX.PIVOT.y)
    cpp=fx.enable_acceleration()
    var layer:=CanvasLayer.new()
    add_child(layer)
    label=Label.new()
    label.position=Vector2(24,24)
    layer.add_child(label)

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#121824"))
    draw_rect(Rect2(208,468,544,48),Color("#293547"))
    draw_line(Vector2(208,468),Vector2(752,468),Color("#4d627a"))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if UI.physical_key(event)==KEY_ESCAPE:
            get_tree().change_scene_to_file("res://lab/main.tscn")
        elif UI.physical_key(event)==KEY_A:
            cpp=fx.enable_acceleration(not cpp)
        elif UI.physical_key(event)==KEY_SPACE:
            time=0.0
            shown_frame=-1

func _process(delta: float) -> void:
    time=fmod(time+delta,4.0)
    var index: int=int(floor(time*30.0))
    if index==shown_frame:
        return
    shown_frame=index
    var start: int=Time.get_ticks_usec()
    surface.painter.clear()
    fx.draw(surface.painter,float(index)/30.0)
    surface.present()
    label.text="ШАРОВАЯ МОЛНИЯ | %s | %.2f мс | A движок · пробел повтор · Esc меню" % ["C++" if cpp else "GDScript",(Time.get_ticks_usec()-start)/1000.0]
