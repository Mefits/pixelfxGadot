extends Node2D
var time: float=0
var moving: bool=false
var bright: bool=false
var sweep: bool=false
func anchor(name: String,t: float) -> Vector2:
    var offset: float=sin(t*4)*20 if moving else 0.0
    match name:
        "hand":
            if moving and sweep:return Vector2(112+sin(t*3.5)*42,76-cos(t*3.5)*23)
            return Vector2(83+offset,76)
        "target":return Vector2(166,76)
    return Vector2(120,80)
func _draw() -> void:
    draw_rect(Rect2(0,0,240,160),Color("#c2c4ba") if bright else Color("#152030"))
    for x in range(0,240,12):draw_line(Vector2(x,0),Vector2(x,160),Color("#344354") if not bright else Color("#aeb2aa"),.5)
    for y in range(0,160,12):draw_line(Vector2(0,y),Vector2(240,y),Color("#344354") if not bright else Color("#aeb2aa"),.5)
    draw_rect(Rect2(0,128,240,32),Color("#344655") if not bright else Color("#929b91"))
    draw_line(Vector2(0,128),Vector2(240,128),Color("#84918f"),1)
    var h: Vector2=anchor("hand",time)
    draw_line(h+Vector2(-13,24),h+Vector2(-13,-13),Color("#588080"),8)
    draw_circle(h+Vector2(-13,-21),6,Color("#588080"))
    draw_line(h+Vector2(-13,-8),h,Color("#83ada5"),3)
    draw_circle(h,2,Color("#b6d8c7"))
    draw_rect(Rect2(h+Vector2(-17,23),Vector2(8,27)),Color("#588080"))
    var target: Vector2=anchor("target",time)
    draw_circle(target,9,Color("#946c66"),false,1)
    draw_line(target-Vector2(0,10),target+Vector2(0,52),Color("#946c66"))
