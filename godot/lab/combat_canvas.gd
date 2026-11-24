extends Node2D
const SKIN=preload("res://addons/creature/skin.gd")
var world
var debug: bool=false
func _draw() -> void:
    draw_rect(Rect2(0,0,320,180),Color("#172230"))
    draw_rect(Rect2(0,54,320,91),Color("#202d3c"))
    for i in range(0,320,32):
        draw_rect(Rect2(i+2,62,28,76),Color("#29394a"))
        draw_rect(Rect2(i+5,65,22,3),Color("#354b60"))
        draw_line(Vector2(i+16,68),Vector2(i+16,135),Color("#243344"))
    draw_rect(Rect2(0,146,320,34),Color("#303d4a"))
    draw_rect(Rect2(0,146,320,2),Color("#829098"))
    for x in range(0,320,16):draw_line(Vector2(x,150),Vector2(x-12,180),Color("#26333e"))
    if world==null:return
    for f in [world.a,world.b]:
        draw_ellipse_shadow(f.pos)
        SKIN.draw_body(self,f.rig,f.pos,f.facing,(f.tint.lightened(.45) if f.flash>0 and world.modern else f.tint) if f.hp>0 else f.tint.darkened(.6),debug)
        if f.guard:
            var angle: float=0 if f.facing>0 else PI
            draw_arc(f.point("chest"),13,angle-PI/2,angle+PI/2,18,Color("#7de2df"),1.2)
        if debug:
            draw_circle(f.point("hand_near"),2,Color("#ffcf69"),false)

func draw_ellipse_shadow(p: Vector2) -> void:
    draw_set_transform(Vector2(p.x,146),0,Vector2(1,.22))
    draw_circle(Vector2.ZERO,10,Color("#192630"),false)
    draw_set_transform(Vector2.ZERO)
