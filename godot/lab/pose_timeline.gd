extends Control
## Two lanes: exact pose keys and event markers. Click a marker to seek exactly.
signal value_changed(value: float)
signal marker_selected(lane: int,index: int)
signal marker_moved(lane: int,index: int,time: float)
var drag_lane: int=-1
var drag_index: int=-1
var press_x: float=0
var drag_time: float=0
var moving_marker: bool=false
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
        draw_colored_polygon(PackedVector2Array([Vector2(x,28),Vector2(x+5,37),Vector2(x-5,37)]),Color("#bd92f7") if event.kind=="vfx" else Color("#e9ad62"))
    draw_line(Vector2(at(value),0),Vector2(at(value),size.y),Color.WHITE,1)
    if moving_marker:
        var x: float=at(drag_time)
        draw_line(Vector2(x,12),Vector2(x,size.y),Color("#e6b670"),2)
        draw_string(font,Vector2(clampf(x+5,LEFT,size.x-48),12),"%.3f"%drag_time,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#f5cc90"))
func _gui_input(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        if not e.pressed:
            if moving_marker:
                marker_moved.emit(drag_lane,drag_index,drag_time)
            dragging=false
            moving_marker=false
            drag_lane=-1
            drag_index=-1
            queue_redraw()
            accept_event()
            return
        dragging=true
        press_x=e.position.x
        drag_lane=-1
        drag_index=-1
        moving_marker=false
        var lane: int=0 if e.position.y>=13 and e.position.y<27 else (1 if e.position.y>=27 else -1)
        if lane>=0:
            var arr: Array=clip.get("keys" if lane==0 else "events",[])
            var best: float=8
            for i in range(arr.size()):
                var dist: float=absf(at(arr[i].t)-e.position.x)
                if dist<best:
                    best=dist
                    drag_lane=lane
                    drag_index=i
            if drag_index>=0:
                drag_time=float(arr[drag_index].t)
                value_changed.emit(drag_time)
                marker_selected.emit(lane,drag_index)
                accept_event()
                return
        _seek(e.position.x)
        accept_event()
    elif e is InputEventMouseMotion and dragging:
        if drag_index>=0:
            if absf(e.position.x-press_x)>4:moving_marker=true
            if moving_marker:
                var t: float=_time_at(e.position.x)
                drag_time=clampf(snappedf(t,.01),0,max_value)
                if e.shift_pressed:drag_time=t
                queue_redraw()
        else:_seek(e.position.x)
        accept_event()

func _time_at(x: float) -> float:
    return clampf((x-LEFT)/maxf(1,size.x-LEFT-10),0,1)*max_value

func _seek(x: float) -> void:
    value_changed.emit(_time_at(x))
