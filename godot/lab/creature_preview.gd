extends Node2D
const SKIN=preload("res://addons/creature/skin.gd")
var rig
var origin:=Vector2(72,84)
var debug: bool=true
var tint: Color=Color("#5aafdc")
var selected: String="hand_near"
func _draw() -> void:
    draw_rect(Rect2(0,0,144,108),Color("#151e2b"))
    for x in range(0,144,8):
        draw_line(Vector2(x,0),Vector2(x,108),Color("#202c3c"),1.0)
    for y in range(0,108,8):
        draw_line(Vector2(0,y),Vector2(144,y),Color("#202c3c"),1.0)
    draw_line(Vector2(0,origin.y),Vector2(144,origin.y),Color("#647389"))
    if rig!=null:
        SKIN.draw_body(self,rig,origin,1,tint,debug)
        draw_arc(origin+rig.point(selected),3,0,TAU,16,Color("#ffffff"),.7)
