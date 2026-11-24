extends Node2D
const SKIN=preload("res://addons/creature/skin.gd")
var rig
var origin:=Vector2(96,112)
var debug: bool=true
var selected: String="hand_near"
func _draw() -> void:
    draw_rect(Rect2(0,0,192,144),Color("#151e2b"))
    for x in range(0,192,8):
        draw_line(Vector2(x,0),Vector2(x,144),Color("#202c3c"),.25)
    for y in range(0,144,8):
        draw_line(Vector2(0,y),Vector2(192,y),Color("#202c3c"),.25)
    draw_line(Vector2(0,origin.y),Vector2(192,origin.y),Color("#647389"))
    if rig!=null:
        SKIN.draw_body(self,rig,origin,1,Color("#5aafdc"),debug)
        draw_arc(origin+rig.point(selected),3,0,TAU,16,Color("#ffffff"),.7)
