extends Control
const P=preload("res://addons/pixelfx/composer/preset.gd")
signal seek_requested(time: float)
signal layer_requested(index: int)
var preset: Dictionary={}
var time: float=0
var selected: int=0
var duration_override: float=0
var zoom: float=1
var view_start: float=0
const COLORS=[Color("#70b6df"),Color("#e1b46b"),Color("#9e92d5"),Color("#8bc1a0")]
const LEFT: float=32
func total() -> float:
    return maxf(.05,maxf(duration_override,P.duration(preset))) if not preset.is_empty() else .05
func span() -> float:
    return total()/zoom
func _clamp_view() -> void:
    view_start=clampf(view_start,0,maxf(0,total()-span()))
func reset_view() -> void:
    zoom=1
    view_start=0
    queue_redraw()
func time_at(x: float) -> float:
    return clampf(view_start+clampf((x-LEFT)/maxf(1,size.x-LEFT-4),0,1)*span(),0,total())
func x_at(t: float) -> float:
    return LEFT+(t-view_start)/span()*(size.x-LEFT-4)
func row_height() -> float:
    return minf(13.0,(size.y-19)/maxi(1,preset.layers.size()))
func zoom_at(factor: float,x: float) -> void:
    var focus: float=time_at(x)
    var fraction: float=clampf((x-LEFT)/maxf(1,size.x-LEFT-4),0,1)
    zoom=clampf(zoom*factor,1,8)
    view_start=focus-fraction*span()
    _clamp_view()
    queue_redraw()
func _bar(a: float,b: float,y: float,h: float,c: Color,outline: bool=false) -> void:
    var x0: float=maxf(LEFT,x_at(a))
    var x1: float=minf(size.x-4,x_at(b))
    if x1<=x0:return
    draw_rect(Rect2(x0,y,x1-x0,h),c,not outline,1)
func _draw() -> void:
    if preset.is_empty():return
    _clamp_view()
    var h: float=row_height()
    var font: Font=ThemeDB.fallback_font
    draw_rect(Rect2(0,0,size.x,size.y),Color("#192634"))
    for i in range(5):
        var x: float=LEFT+(size.x-LEFT-4)*i/4.0
        draw_line(Vector2(x,14),Vector2(x,size.y),Color("#405064"),1)
        draw_string(font,Vector2(minf(x-4,size.x-29),11),"%.2f"%(view_start+span()*i/4),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a6b7c9"))
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        var y: float=17+i*h
        var a: float=float(l.start)
        var b: float=a+float(l.duration)
        var end: float=a+P.layer_duration(l)
        var c: Color=COLORS[i%4] if l.enabled else Color("#45515c")
        if i==selected:draw_rect(Rect2(0,y,size.x,h),Color("#334657"))
        draw_string(font,Vector2(4,y+h-2),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,mini(10,int(h)),Color.WHITE)
        if end>b:_bar(b,end,y,maxf(2,h-2),Color(c.r,c.g,c.b,.35))
        _bar(a,b,y,maxf(2,h-2),c)
        if i==selected:_bar(a,end,y,maxf(2,h-2),Color.WHITE,true)
    if time>=view_start and time<=view_start+span():
        var x: float=x_at(time)
        draw_line(Vector2(x,12),Vector2(x,size.y),Color("#ffffff"),1.5)
func _gui_input(e: InputEvent) -> void:
    if preset.is_empty():return
    if e is InputEventMouseButton and e.pressed:
        if e.button_index==MOUSE_BUTTON_WHEEL_UP or e.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            zoom_at(1.5 if e.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.5,e.position.x)
            accept_event()
        elif e.button_index==MOUSE_BUTTON_LEFT:
            if e.position.y>=17:
                var row: int=int(floor((e.position.y-17)/row_height()))
                if row>=0 and row<preset.layers.size():layer_requested.emit(row)
            if e.position.x>=LEFT:seek_requested.emit(time_at(e.position.x))
            accept_event()
    elif e is InputEventMouseMotion:
        if e.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
            view_start-=e.relative.x/maxf(1,size.x-LEFT-4)*span()
            _clamp_view()
            queue_redraw()
            accept_event()
        elif e.button_mask&MOUSE_BUTTON_MASK_LEFT:
            seek_requested.emit(time_at(e.position.x))
            accept_event()
