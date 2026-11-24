extends Control
## Two lanes: exact pose keys and event markers. Click a marker to seek exactly.
signal value_changed(value: float)
signal marker_selected(lane: int,index: int)
var value: float=0:
    set(v):
        value=clampf(v,0,max_value)
        queue_redraw()
var max_value: float=1
var step: float=1.0/60
var clip: Dictionary={}
var dragging: bool=false
const LEFT: float=78
func at(t: float) -> float:
    return LEFT+clampf(t/maxf(.001,max_value),0,1)*(size.x-LEFT-10)
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("#1c2836"))
    var font: Font=ThemeDB.fallback_font
    for i in range(6):
        var x: float=at(max_value*i/5.0)
        draw_line(Vector2(x,0),Vector2(x,size.y),Color("#34475a"))
        draw_string(font,Vector2(x-10,11),"%.2f"%(max_value*i/5),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#9fb3c4"))
    draw_string(font,Vector2(6,24),"Позы",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#a9d5ee"))
    draw_string(font,Vector2(6,37),"События",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#efc180"))
    for key in clip.get("keys",[]):
        var x: float=at(key.t)
        var c: Color=Color("#f1f7fc") if absf(float(key.t)-value)<.0001 else Color("#79b9d4")
        draw_colored_polygon(PackedVector2Array([Vector2(x,14),Vector2(x+5,20),Vector2(x,26),Vector2(x-5,20)]),c)
    for event in clip.get("events",[]):
        var x: float=at(event.t)
        draw_colored_polygon(PackedVector2Array([Vector2(x,28),Vector2(x+5,37),Vector2(x-5,37)]),Color("#e9ad62"))
    draw_line(Vector2(at(value),0),Vector2(at(value),size.y),Color.WHITE,1)
func _gui_input(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        dragging=e.pressed
        if e.pressed:
            var lane: int=0 if e.position.y>=13 and e.position.y<27 else (1 if e.position.y>=27 else -1)
            if lane>=0:
                var arr: Array=clip.get("keys" if lane==0 else "events",[])
                for i in range(arr.size()):
                    if absf(at(arr[i].t)-e.position.x)<=7:
                        value_changed.emit(float(arr[i].t))
                        marker_selected.emit(lane,i)
                        accept_event()
                        return
            _seek(e.position.x)
        accept_event()
    elif e is InputEventMouseMotion and dragging:
        _seek(e.position.x)
        accept_event()
func _seek(x: float) -> void:
    value_changed.emit(clampf((x-LEFT)/maxf(1,size.x-LEFT-10),0,1)*max_value)
