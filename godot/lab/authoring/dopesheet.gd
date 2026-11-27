extends "res://lab/pose_timeline.gd"
## Frame-based v1 document timeline; gait goals are phase-relative, not fake time keys.
signal goal_selected(index:int)
var curve_mode:bool=false
var curve_keys:Array=[]
var curve_label:String=""
signal curve_edited(index:int,value:float)
var curve_drag_index:int=-1
var curve_drag_start:float=0.
var curve_drag_value:float=0.
var curve_drag_span:float=0.
var curve_drag_y:float=0.
func visible_start()->float:
    return 0. if clip.get("gait",false) else float(clip.get("start",0))

func at(t:float)->float:
    var start:float=visible_start()
    return LEFT+clampf((t-start)/maxf(1.,max_value-start),0.,1.)*(size.x-LEFT-10)

func _time_at(x:float)->float:
    var start:float=visible_start()
    return start+clampf((x-LEFT)/maxf(1.,size.x-LEFT-10),0.,1.)*maxf(0.,max_value-start)

func _seek(x:float)->void:
    var start:float=visible_start()
    value_changed.emit(clampf(start+snappedf(_time_at(x)-start,maxf(step,.0001)),start,max_value))

func _draw()->void:
    if curve_mode:
        draw_curve()
        return
    draw_rect(Rect2(Vector2.ZERO,size),Color("#14202c"))
    var font:Font=ThemeDB.fallback_font
    var start:float=float(clip.get("start",0))
    var gait:bool=bool(clip.get("gait",false))
    if gait:start=0.
    for i in range(3):
        draw_rect(Rect2(0,25+i*24,size.x,24),Color("#1e2d3c") if i%2==0 else Color("#192633"))
    var span:float=max_value-start
    var interval:int=1 if span<=12. else (5 if span<=40. else (10 if span<=100. else 30))
    for f in range(int(start),int(max_value)+1,interval):
        var x:float=at(f)
        draw_line(Vector2(x,19),Vector2(x,size.y),Color("#35485a"))
        draw_string(font,Vector2(x+2,20),str(f if gait else f-int(start)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a9bac8"))
    for i in range(3):
        draw_string(font,Vector2(6,42+i*24),["Позы","Контакт","Цели"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#d5e1ed"))
    for i in clip.get("keys",[]).size():
        var x:float=at(clip.keys[i].t)
        var c:Color=Color.WHITE if absf(float(clip.keys[i].t)-value)<.0001 else Color("#79b9d4")
        draw_colored_polygon(PackedVector2Array([Vector2(x,29),Vector2(x+6,37),Vector2(x,45),Vector2(x-6,37)]),c)
    for event in clip.get("events",[]):
        var x:float=at(event.t)
        draw_colored_polygon(PackedVector2Array([Vector2(x,53),Vector2(x+6,68),Vector2(x-6,68)]),Color("#e9ad62"))
    for goal in clip.get("goals",[]):
        var x:float=at(goal.t)
        var lo:float=at(maxf(start,goal.t-goal.radius))
        var hi:float=at(minf(max_value,goal.t+goal.radius))
        draw_rect(Rect2(lo,79,hi-lo,11),Color("#527d74"))
        draw_line(Vector2(x,76),Vector2(x,94),Color("#a6dfbf"),2)
    if gait:
        draw_string(font,Vector2(LEFT+8,90),"Цели бега привязаны к фазе шага · редактируются во вкладке Цели",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#9fb3c4"))
    draw_line(Vector2(at(value),0),Vector2(at(value),size.y),Color("#e9d38a"),2)
    if moving_marker:draw_line(Vector2(at(drag_time),23),Vector2(at(drag_time),size.y),Color.CORAL,2)

func draw_curve()->void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("#14202c"))
    var font:Font=ThemeDB.fallback_font
    if curve_keys.is_empty():
        draw_string(font,Vector2(12,40),"График доступен для ключевых действий; бег управляется процедурно.",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#b0bdca"))
        return
    var lo:float=INF
    var hi:float=-INF
    for p in curve_keys:
        lo=minf(lo,p.y)
        hi=maxf(hi,p.y)
    lo-=5.
    hi+=5.
    if curve_drag_index>=0:
        lo=minf(lo,curve_drag_value-5.)
        hi=maxf(hi,curve_drag_value+5.)
    draw_string(font,Vector2(5,13),curve_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c7d5e1"))
    for i in 3:
        var y:float=20.+i*34.
        draw_line(Vector2(LEFT,y),Vector2(size.x-10,y),Color("#35485a"))
        draw_string(font,Vector2(5,y+9),"%.1f°"%lerpf(hi,lo,i/2.),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a9bac8"))
    var prev:=Vector2.ZERO
    for i in curve_keys.size():
        var p:Vector2=curve_keys[i]
        if i==curve_drag_index:p.y=curve_drag_value
        var pos:=Vector2(at(p.x),20.+(hi-p.y)/(hi-lo)*68.)
        if i>0:draw_line(prev,pos,Color("#79b9d4"),2)
        draw_circle(pos,3.5,Color("#e9d38a") if absf(p.x-value)<.51 else Color("#79b9d4"))
        prev=pos
    draw_line(Vector2(at(value),0),Vector2(at(value),size.y),Color("#e9d38a"),2)

func _gui_input(e:InputEvent)->void:
    if curve_mode:
        if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
            if not e.pressed:
                if curve_drag_index>=0 and not is_equal_approx(curve_drag_value,curve_drag_start):
                    var index:int=curve_drag_index
                    var next:float=curve_drag_value
                    curve_drag_index=-1
                    curve_edited.emit(index,next)
                curve_drag_index=-1
                queue_redraw()
                accept_event()
                return
            var best:float=8.
            var index:int=-1
            for i in curve_keys.size():
                var d:float=absf(at(curve_keys[i].x)-e.position.x)
                if d<best:
                    best=d
                    index=i
            if index>=0:
                var lo:float=INF
                var hi:float=-INF
                for p in curve_keys:
                    lo=minf(lo,p.y)
                    hi=maxf(hi,p.y)
                curve_drag_span=hi-lo+10.
                curve_drag_start=curve_keys[index].y
                curve_drag_value=curve_drag_start
                curve_drag_y=e.position.y
                curve_drag_index=index
                value_changed.emit(curve_keys[index].x)
                marker_selected.emit(0,index)
            else:_seek(e.position.x)
            accept_event()
        elif e is InputEventMouseMotion and curve_drag_index>=0:
            curve_drag_value=clampf(curve_drag_start+(curve_drag_y-e.position.y)*curve_drag_span/68.,-360.,360.)
            queue_redraw()
            accept_event()
        return
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed and e.position.y>=73:
        var best:float=9.
        var index:int=-1
        for g in clip.get("goals",[]):
            var d:float=absf(at(g.t)-e.position.x)
            if d<best:
                best=d
                index=g.index
        if index>=0:
            _seek(e.position.x)
            goal_selected.emit(index)
            accept_event()
            return
    if e is InputEventMouseButton or e is InputEventMouseMotion:
        var copy=e.duplicate()
        copy.position=Vector2(e.position.x,20. if e.position.y>=25 and e.position.y<49 else (32. if e.position.y>=49 and e.position.y<73 else 5.))
        super._gui_input(copy)
    else:super._gui_input(e)
