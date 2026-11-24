extends Node2D
const CREATURE=preload("res://addons/creature/physical_creature.gd")
const ROOM: Vector2=Vector2(960,540)
var boxes: Array[Rect2]=[
    Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),
    Rect2(0,470,960,70),Rect2(230,432,72,38),Rect2(302,390,90,80),
    Rect2(470,360,120,20),Rect2(660,300,130,20),Rect2(790,300,28,170),
    Rect2(60,320,145,18),Rect2(250,225,160,18),Rect2(530,180,220,18),
    Rect2(836,414,124,56)]
var creature
var debug: bool=true
var paused: bool=false
var slow: bool=false
var tail: int=5
var legs_on: bool=true
var mass: float=1
var jump_latch: bool=false
var step_ms: float=0
var hud: Label
var info: Label
var cam:=Vector2.ZERO
var trail: Array[Vector2]=[]
var track_clock: float=0
var dragging: bool=false
var selected: int=-1

func _ready() -> void:
    var layer:=CanvasLayer.new()
    add_child(layer)
    var title:=Label.new()
    title.position=Vector2(18,10)
    title.text="PHYSICS LAB / independent physical body"
    title.add_theme_font_size_override("font_size",22)
    layer.add_child(title)
    hud=Label.new()
    hud.position=Vector2(18,42)
    layer.add_child(hud)
    info=Label.new()
    info.position=Vector2(18,505)
    info.text="A/D move | W/Space jump | auto ledge | Q legs | 1/2 tail | 3/4 mass | V debug | P pause | X slow | R reset | Esc"
    info.add_theme_font_size_override("font_size",14)
    layer.add_child(info)
    _reset()

func _reset() -> void:
    creature=CREATURE.new(Vector2(135,440),boxes,tail,mass,legs_on)
    trail.clear()
    dragging=false
    selected=-1

func _physics_process(dt: float) -> void:
    if creature==null:return
    var pressed: bool=Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
    var jump: bool=pressed and not jump_latch
    jump_latch=pressed
    if not paused:
        var axis: float=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
        var start: int=Time.get_ticks_usec()
        if dragging and selected>=0:
            var n: Dictionary=creature.body.nodes[selected]
            var delta: Vector2=get_global_mouse_position()-Vector2(n.p)
            creature.body.force(selected,(delta*95-Vector2(n.v)*12).limit_length(1600))
        creature.advance(dt*(.25 if slow else 1),axis,jump)
        step_ms=(Time.get_ticks_usec()-start)/1000.0
        track_clock+=dt
        if track_clock>.035:
            track_clock=0
            trail.append(creature.body.center_of_mass())
            if trail.size()>60:trail.pop_front()
    _update_hud()
    queue_redraw()

func _update_hud() -> void:
    hud.text="Segments %d | feet %d/4 | mass x%.1f | %s | constraint %.2f px | penetration %.3f | %.2f ms CPU | %s"%[
        creature.body.nodes.size(),creature.limbs.support_count,mass,"GROUND" if creature.grounded else "AIR",creature.body.max_error,creature.body.penetration(),step_ms,"PAUSED" if paused else ("SLOW" if slow else "120 Hz")]

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,ROOM),Color("#141d29"))
    for x in range(0,960,24):draw_line(Vector2(x,80),Vector2(x,470),Color("#202c3a"))
    for y in range(80,470,24):draw_line(Vector2(0,y),Vector2(960,y),Color("#202c3a"))
    for box in boxes:
        draw_rect(box,Color("#344759"))
        draw_line(box.position,Vector2(box.end.x,box.position.y),Color("#788e99"),2)
        draw_rect(box,Color("#273645"),false,1)
    if creature==null:return
    var body=creature.body
    if debug and trail.size()>1:draw_polyline(PackedVector2Array(trail),Color("#537b8e"),1)
    if creature.limbs.enabled:
        for l in creature.limbs.legs:
            var hip: Vector2=body.nodes[l.parent].p
            var knee: Vector2=l.knee
            var tip: Vector2=l.get("tip",l.foot)
            var col: Color=Color("#46736e") if l.side<0 else Color("#8cbcab")
            draw_line(hip,knee,Color("#101923"),5)
            draw_line(knee,tip,Color("#101923"),5)
            draw_line(hip,knee,col,3)
            draw_line(knee,tip,col,3)
            draw_circle(tip,2.5,col)
            if debug and l.planted:
                draw_circle(l.foot,3,Color("#e3c77d"),false,1)
            if debug and l.swing:
                draw_line(tip,l.target,Color("#8b8f9f"),1)
    for i in range(body.links.size()-1,-1,-1):
        var l: Dictionary=body.links[i]
        var a: Dictionary=body.nodes[l.a]
        var b: Dictionary=body.nodes[l.b]
        draw_line(a.p,b.p,Color("#111923"),minf(a.r,b.r)*2+3)
        draw_line(a.p,b.p,Color("#537b76"),minf(a.r,b.r)*2)
    for i in range(body.nodes.size()-1,-1,-1):
        var n: Dictionary=body.nodes[i]
        draw_circle(n.p,n.r+1,Color("#111923"))
        draw_circle(n.p,n.r,Color("#81b3a0") if i<2 else Color("#537b76"))
        if debug:
            draw_arc(n.p,n.r,0,TAU,24,Color("#a7ded0"),1)
            draw_line(n.p,Vector2(n.p)+Vector2(n.v)*.12,Color("#f2b869"),1.5)
            if n.ground or n.wall:
                draw_line(n.p,Vector2(n.p)+Vector2(n.normal).normalized()*15,Color("#f0836d"),2)
    var head: Vector2=body.nodes[0].p
    draw_circle(head+Vector2(creature.direction*3,-2),1.6,Color("#f8ebbb"))
    if debug:
        var center: Vector2=body.center_of_mass()
        draw_line(center-Vector2(4,0),center+Vector2(4,0),Color("#ffffff"))
        draw_line(center-Vector2(0,4),center+Vector2(0,4),Color("#ffffff"))
    if creature.grip_index>=0:
        draw_line(head,creature.grip_target,Color("#e9be70"),2)
        draw_circle(creature.grip_target,3,Color("#e9be70"))

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        match e.keycode:
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_R:_reset()
            KEY_Q:
                legs_on=not legs_on
                creature.limbs.enabled=legs_on
                creature.limbs.release_all()
            KEY_V:debug=not debug
            KEY_P:paused=not paused
            KEY_X:slow=not slow
            KEY_1:tail=maxi(0,tail-1);_reset()
            KEY_2:tail=mini(12,tail+1);_reset()
            KEY_3:mass=maxf(.5,mass-.25);_reset()
            KEY_4:mass=minf(3,mass+.25);_reset()
    elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        dragging=e.pressed
        selected=-1
        if dragging:
            var best: float=18
            for i in range(creature.body.nodes.size()):
                var d: float=get_global_mouse_position().distance_to(creature.body.nodes[i].p)
                if d<best:best=d;selected=i
