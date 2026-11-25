extends Node2D
const SKIN=preload("res://addons/creature/skin.gd")
const INK48=preload("res://lab/anatomy_rd/ink_046.gd")
var bag_visible:bool=false
var bag_x:float=36.0
var rd_skin:bool=false
var rig
var ghost_rig=preload("res://addons/creature/rig.gd").humanoid()
var ghost_poses: Array=[]
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
    if bag_visible:
        draw_set_transform(origin)
        draw_line(Vector2(bag_x+5,-60),Vector2(bag_x+5,-53),Color("#9c9a8a"),.65)
        draw_rect(Rect2(bag_x,-53,10,47),Color("#75634f"))
        draw_circle(Vector2(bag_x+5,-53),5,Color("#75634f"))
        draw_circle(Vector2(bag_x+5,-6),5,Color("#75634f"))
        draw_line(Vector2(bag_x,-48),Vector2(bag_x,-10),Color("#c0aa87"),.65)
        for y in [-47,-33,-19]:draw_line(Vector2(bag_x,y),Vector2(bag_x+10,y),Color("#a58b67"),.45)
        draw_set_transform(Vector2.ZERO)
    if rig!=null:
        for g in ghost_poses:
            ghost_rig.evaluate(g.pose)
            for j in ghost_rig.joints:
                if not str(j.parent).is_empty():
                    draw_line(origin+ghost_rig.point(j.parent),origin+ghost_rig.point(j.id),g.color,1)
        if rd_skin:
            draw_set_transform(origin)
            INK48.actor(self,rig.points,0,"hand_near")
            draw_set_transform(Vector2.ZERO)
            if debug:
                for j in rig.joints:draw_circle(origin+rig.point(j.id),.9,Color("#d9e9ec"))
        else:SKIN.draw_body(self,rig,origin,1,tint,debug)
        draw_arc(origin+rig.point(selected),3,0,TAU,16,Color("#ffffff"),.7)
