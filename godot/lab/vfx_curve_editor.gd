extends Control
## Independent curve editor. Points are [normalized time, absolute value].
signal points_changed(points: Array)
const P=preload("res://addons/pixelfx/composer/preset.gd")
var points: Array=[]
var bounds: Array=[0.0,1.0]
var active: bool=false
var dragging: int=-1
var chosen: int=-1
var cursor_u: float=-1

func _ready() -> void:
    custom_minimum_size=Vector2(225,142)
    mouse_filter=Control.MOUSE_FILTER_STOP
    focus_mode=Control.FOCUS_NONE

func configure(data: Array,limits: Array,enabled: bool) -> void:
    points=data.duplicate(true)
    bounds=limits.duplicate()
    active=enabled
    dragging=-1
    chosen=-1
    queue_redraw()

func set_cursor(u: float) -> void:
    if is_equal_approx(u,cursor_u):return
    cursor_u=u
    queue_redraw()

func _plot() -> Rect2:
    return Rect2(Vector2(32,12),Vector2(maxf(1,size.x-44),maxf(1,size.y-33)))

func _position(pt: Array) -> Vector2:
    var rect: Rect2=_plot()
    var v: float=(float(pt[1])-float(bounds[0]))/(float(bounds[1])-float(bounds[0]))
    return rect.position+Vector2(float(pt[0])*rect.size.x,(1-v)*rect.size.y)

func _point(q: Vector2) -> Array:
    var rect: Rect2=_plot()
    var n: Vector2=(q-rect.position)/rect.size
    return [clampf(n.x,0,1),lerpf(float(bounds[0]),float(bounds[1]),1-clampf(n.y,0,1))]

func _draw() -> void:
    var rect: Rect2=_plot()
    var font: Font=get_theme_default_font()
    draw_rect(rect,Color("#192634"))
    for i in range(5):
        var f: float=float(i)/4
        var x: float=rect.position.x+rect.size.x*f
        var y: float=rect.position.y+rect.size.y*f
        draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("#34465a"))
        draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color("#34465a"))
        if i%2==0:
            draw_string(font,Vector2(0,y+4),"%.1f"%lerpf(float(bounds[1]),float(bounds[0]),f),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a2b5c5"))
            draw_string(font,Vector2(x-8,rect.end.y+14),"%d%%"%int(f*100),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a2b5c5"))
    if cursor_u>=0 and cursor_u<=1:
        var x: float=rect.position.x+rect.size.x*cursor_u
        draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("#d6af65"),1)
    var ink: Color=Color("#79d5cf") if active else Color("#8093a2")
    for i in range(1,points.size()):
        draw_line(_position(points[i-1]),_position(points[i]),ink,2,true)
    for i in range(points.size()):
        draw_circle(_position(points[i]),5 if i==chosen else 3.5,Color("#f6d78a") if i==chosen else ink)

func _nearest(q: Vector2) -> int:
    var index: int=-1
    var best: float=9.0
    for i in range(points.size()):
        var d: float=q.distance_to(_position(points[i]))
        if d<best:
            index=i
            best=d
    return index

func _publish() -> void:
    points_changed.emit(points.duplicate(true))
    queue_redraw()

func _gui_input(e: InputEvent) -> void:
    if not active:return
    if e is InputEventMouseButton:
        if e.button_index==MOUSE_BUTTON_LEFT:
            if not e.pressed:
                dragging=-1
                accept_event()
                return
            if not _plot().grow(8).has_point(e.position):return
            chosen=_nearest(e.position)
            if chosen<0 and points.size()<P.MAX_POINTS:
                var pt: Array=_point(e.position)
                for i in range(1,points.size()):
                    if float(pt[0])>float(points[i-1][0])+.01 and float(pt[0])<float(points[i][0])-.01:
                        points.insert(i,pt)
                        chosen=i
                        _publish()
                        break
            dragging=chosen
            queue_redraw()
            accept_event()
        elif e.button_index==MOUSE_BUTTON_RIGHT and e.pressed:
            var i: int=_nearest(e.position)
            if i>0 and i<points.size()-1:
                points.remove_at(i)
                dragging=-1
                chosen=-1
                _publish()
            accept_event()
    elif e is InputEventMouseMotion and dragging>=0:
        if (e.button_mask&MOUSE_BUTTON_MASK_LEFT)==0:
            dragging=-1
            return
        var pt: Array=_point(e.position)
        if dragging==0:pt[0]=0.0
        elif dragging==points.size()-1:pt[0]=1.0
        else:
            var lo: float=float(points[dragging-1][0])+P.MIN_GAP
            var hi: float=float(points[dragging+1][0])-P.MIN_GAP
            pt[0]=clampf(float(pt[0]),lo,hi)
        points[dragging]=pt
        _publish()
        accept_event()
