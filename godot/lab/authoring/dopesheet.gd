extends "res://lab/pose_timeline.gd"
## Frame-based v1 document timeline; gait goals are phase-relative, not fake time keys.
signal goal_selected(index:int)
var curve_mode:bool=false
var curve_keys:Array=[]
var curve_label:String=""
func _draw()->void:
    if curve_mode:
        draw_curve()
        return
    draw_rect(Rect2(Vector2.ZERO,size),Color("#14202c"))
    var font:Font=ThemeDB.fallback_font
    var start:float=float(clip.get("start",0))
    var gait:bool=bool(clip.get("gait",false))
    if not gait:
        draw_rect(Rect2(LEFT,0,at(start)-LEFT,size.y),Color("#243441"))
        draw_string(font,Vector2(LEFT+4,13),"прогрев",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a1adba"))
    for i in range(3):
        draw_rect(Rect2(0,25+i*24,size.x,24),Color("#1e2d3c") if i%2==0 else Color("#192633"))
    var interval:int=15 if max_value<=150 else 30
    for f in range(0,int(max_value)+1,interval):
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
    draw_string(font,Vector2(5,13),curve_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c7d5e1"))
    for i in 3:
        var y:float=20.+i*34.
        draw_line(Vector2(LEFT,y),Vector2(size.x-10,y),Color("#35485a"))
        draw_string(font,Vector2(5,y+9),"%.1f°"%lerpf(hi,lo,i/2.),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a9bac8"))
    var prev:=Vector2.ZERO
    for i in curve_keys.size():
        var p:Vector2=curve_keys[i]
        var pos:=Vector2(at(p.x),20.+(hi-p.y)/(hi-lo)*68.)
        if i>0:draw_line(prev,pos,Color("#79b9d4"),2)
        draw_circle(pos,3.5,Color("#e9d38a") if absf(p.x-value)<.51 else Color("#79b9d4"))
        prev=pos
    draw_line(Vector2(at(value),0),Vector2(at(value),size.y),Color("#e9d38a"),2)

func _gui_input(e:InputEvent)->void:
    if curve_mode:
        if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
            var best:float=8.
            var index:int=-1
            for i in curve_keys.size():
                var d:float=absf(at(curve_keys[i].x)-e.position.x)
                if d<best:
                    best=d
                    index=i
            if index>=0:
                value_changed.emit(curve_keys[index].x)
                marker_selected.emit(0,index)
            else:_seek(e.position.x)
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
