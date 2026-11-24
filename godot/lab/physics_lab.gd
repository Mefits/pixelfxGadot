extends Node2D
const UI=preload("res://lab/ui_ru.gd")
const CREATURE=preload("res://addons/creature/physical_creature.gd")
const INTENT=preload("res://lab/intent_panel.gd")
const TRACK=preload("res://addons/creature/motion_track.gd")
var panel
var ui_layer: CanvasLayer
var mutation_label: Label
var notice: String=""
var notice_until: float=0
const ROOM: Vector2=Vector2(960,540)
var boxes: Array[Rect2]=[
    Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),
    Rect2(0,470,960,70),Rect2(230,432,72,38),Rect2(302,390,90,80),
    Rect2(470,360,120,20),Rect2(660,300,130,20),Rect2(790,300,28,170),
    Rect2(60,320,145,18),Rect2(250,225,160,18),Rect2(530,180,220,18),
    Rect2(836,414,124,56)]
var creature
var debug: bool=false
var motion_on: bool=true
var contact_on: bool=true
var motion_label: Label
var paused: bool=false
var slow: bool=false
var tail: int=2
var attack_latch: bool=false
var dummy: Dictionary={}
var legs_on: bool=true
var walls_on: bool=true
var course: int=0
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
    ui_layer=layer
    var title:=Label.new()
    title.position=Vector2(18,10)
    title.text="ФИЗИКА И ЭВОЛЮЦИЯ / физическое тело"
    title.add_theme_font_size_override("font_size",22)
    layer.add_child(title)
    hud=Label.new()
    hud.position=Vector2(18,42)
    hud.add_theme_font_size_override("font_size",13)
    layer.add_child(hud)
    info=Label.new()
    info.position=Vector2(18,505)
    info.text="A/D ходьба · W/пробел прыжок · F удар · ↑↓ лазание · H атака · M комната · G мишень · R сброс · Esc меню"
    info.add_theme_font_size_override("font_size",13)
    layer.add_child(info)
    mutation_label=Label.new()
    mutation_label.position=Vector2(18,482)
    mutation_label.add_theme_font_size_override("font_size",12)
    layer.add_child(mutation_label)
    motion_label=Label.new()
    motion_label.position=Vector2(18,62)
    motion_label.add_theme_font_size_override("font_size",13)
    layer.add_child(motion_label)
    _reset()

func _reset() -> void:
    if is_instance_valid(panel):panel.queue_free();panel=null
    tail=2
    mass=1
    creature=CREATURE.new(Vector2(135,440),boxes,tail,mass,legs_on)
    creature.attack.set_track(TRACK.load_track())
    creature.surface.enabled=walls_on
    creature.smooth_motion=motion_on
    creature.limbs.adaptive_gait=motion_on
    creature.contact_polish=contact_on
    dummy={"id":"training","p":Vector2(183,446),"r":10.0,"hp":100}
    creature.attack.targets.append(dummy)
    trail.clear()
    dragging=false
    selected=-1

func _physics_process(dt: float) -> void:
    if creature==null:return
    var pressed: bool=Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
    var jump: bool=pressed and not jump_latch
    jump_latch=pressed
    var attack_pressed: bool=Input.is_physical_key_pressed(KEY_F)
    var strike: bool=attack_pressed and not attack_latch
    attack_latch=attack_pressed
    if not paused:
        var axis: float=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
        var start: int=Time.get_ticks_usec()
        if dragging and selected>=0:
            var n: Dictionary=creature.body.nodes[selected]
            var delta: Vector2=get_global_mouse_position()-Vector2(n.p)
            creature.body.force(selected,(delta*95-Vector2(n.v)*12).limit_length(1600))
        var climb: float=float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP))
        if is_instance_valid(panel):
            axis=0
            jump=false
            climb=0
            strike=false
        creature.advance(dt*(.25 if slow else 1),axis,jump,false,climb,strike,pressed)
        step_ms=(Time.get_ticks_usec()-start)/1000.0
        track_clock+=dt
        if track_clock>.035:
            track_clock=0
            trail.append(creature.body.center_of_mass())
            if trail.size()>60:trail.pop_front()
    _update_hud()
    queue_redraw()

func _update_hud() -> void:
    hud.text="Тело %d | опоры %d/%d | масса ×%.1f | %s | ошибка %.2f px | пересеч. %.3f | %.2f мс | %s | стены %s"%[
        creature.body.nodes.size(),creature.limbs.support_count,creature.limbs.legs.size(),creature.mass_scale,("СТЕНА" if creature.surface.active else ("ЗЕМЛЯ" if creature.grounded else "ВОЗДУХ")),creature.body.max_error,creature.body.penetration(),step_ms,"ПАУЗА" if paused else ("МЕДЛЕННО" if slow else "120 Гц"),"вкл." if walls_on else "выкл."]
    hud.text+=" | атака: %s | цель %d"%[UI.label(creature.attack.phase()),dummy.get("hp",100)]
    var vel: Vector2=(Vector2(creature.body.nodes[0].v)+Vector2(creature.body.nodes[1].v))*.5
    var states: Dictionary={"wall":"лазание","ledge":"подтягивание","landing":"приземление","run":"бег","idle":"стойка","rise":"взлёт","fall":"падение","air":"воздух"}
    motion_label.text="%.0f px/с | %s | B мотор: %s · N контакты: %s | посадок %d"%[vel.x,states.get(creature.motion_state,""),"новый" if motion_on else "старый","новые" if contact_on else "старые",creature.landing_count]
    mutation_label.text="1/2 хвост (%d) · 3/4 масса · 5/6 лапы · 7/8 длина (×%.2f) · мутаций %d | Q лапы · C стены · V отладка · X медленно"%[creature.tail_count,creature.limb_scale,creature.mutations]
    if Time.get_ticks_msec()<notice_until:mutation_label.text=notice

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
    if not dummy.is_empty():
        var dp: Vector2=dummy.p
        draw_circle(dp,dummy.r,Color("#965c55") if dummy.hp>0 else Color("#414a54"))
        draw_arc(dp,dummy.r,0,TAU,24,Color("#d19a80"),1)
        draw_rect(Rect2(dp+Vector2(-12,-15),Vector2(24,3)),Color("#273645"))
        draw_rect(Rect2(dp+Vector2(-12,-15),Vector2(24*float(dummy.hp)/100,3)),Color("#db9b73"))
    if debug and trail.size()>1:draw_polyline(PackedVector2Array(trail),Color("#537b8e"),1)
    if creature.limbs.enabled:
        for i in range(creature.limbs.legs.size()):
            var l: Dictionary=creature.limbs.legs[i]
            var attacking: bool=creature.attack.active and i==creature.attack.leg
            if attacking and not creature.attack.visible_pose:continue
            var hip: Vector2=body.nodes[l.parent].p
            var knee: Vector2=l.knee
            var tip: Vector2=l.get("tip",l.foot)
            var col: Color=Color("#46736e") if l.side<0 else Color("#8cbcab")
            draw_line(hip,knee,Color("#101923"),5)
            draw_line(knee,tip,Color("#101923"),5)
            draw_line(hip,knee,col,3)
            draw_line(knee,tip,col,3)
            draw_circle(tip,2.5,col)
            if attacking:
                var claw_axis: Vector2=(tip-knee).normalized()
                draw_line(tip,tip+claw_axis*3,Color("#d5e7d0"),2)
                if debug:
                    draw_arc(creature.attack.desired_tip,3,0,TAU,16,Color("#d7a766"),1)
                    if creature.attack.blocked:draw_line(tip,creature.attack.desired_tip,Color("#c97f6f"),1)
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
    if creature.surface.active and debug:
        var s=creature.surface
        draw_line(Vector2(s.wall_x,s.face.position.y),Vector2(s.wall_x,s.face.end.y),Color("#e9be70"),2)
    if creature.grip_index>=0:
        draw_line(head,creature.grip_target,Color("#e9be70"),2)
        draw_circle(creature.grip_target,3,Color("#e9be70"))

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        match UI.physical_key(e):
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_R:_reset()
            KEY_H:
                if is_instance_valid(panel):panel.queue_free();panel=null
                else:
                    paused=false
                    panel=INTENT.new(creature)
                    ui_layer.add_child(panel)
            KEY_C:
                walls_on=not walls_on
                creature.surface.enabled=walls_on
                if not walls_on:creature.surface.detach()
            KEY_M:
                course=(course+1)%4
                _set_course()
                _reset()
            KEY_Q:
                legs_on=not legs_on
                creature.limbs.enabled=legs_on
                creature.limbs.release_all()
            KEY_B:
                motion_on=not motion_on
                creature.smooth_motion=motion_on
                creature.limbs.adaptive_gait=motion_on
            KEY_N:
                contact_on=not contact_on
                creature.contact_polish=contact_on
                creature.limbs.contact_polish=contact_on
                creature.landing_time=0
            KEY_V:debug=not debug
            KEY_G:
                dummy.p=get_global_mouse_position()
                dummy.hp=100
            KEY_P:paused=not paused
            KEY_X:slow=not slow
            KEY_1:_mutation(creature.change_tail(-1));selected=-1;dragging=false
            KEY_2:_mutation(creature.change_tail(1))
            KEY_3:_mutation(creature.change_mass(-.25))
            KEY_4:_mutation(creature.change_mass(.25))
            KEY_5:_mutation(creature.change_legs(false))
            KEY_6:_mutation(creature.change_legs(true))
            KEY_7:_mutation(creature.change_reach(-.1))
            KEY_8:_mutation(creature.change_reach(.1))
    elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
        dragging=e.pressed
        selected=-1
        if dragging:
            var best: float=18
            for i in range(creature.body.nodes.size()):
                var d: float=get_global_mouse_position().distance_to(creature.body.nodes[i].p)
                if d<best:best=d;selected=i

func _set_course() -> void:
    if course==0:
        boxes.assign([Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),Rect2(0,470,960,70),Rect2(230,432,72,38),Rect2(302,390,90,80),Rect2(470,360,120,20),Rect2(660,300,130,20),Rect2(790,300,28,170),Rect2(60,320,145,18),Rect2(250,225,160,18),Rect2(530,180,220,18),Rect2(836,414,124,56)])
    elif course==1:
        boxes.assign([Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),Rect2(0,470,960,70),Rect2(280,215,65,255),Rect2(345,215,110,18),Rect2(475,418,140,32),Rect2(650,360,90,110),Rect2(800,200,45,270),Rect2(845,280,115,18)])
    elif course==2:
        boxes.assign([Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),Rect2(0,470,960,70)])
    else:
        boxes.assign([Rect2(-40,0,40,540),Rect2(960,0,40,540),Rect2(0,-40,960,40),Rect2(0,470,960,70),Rect2(220,448,65,22),Rect2(285,426,65,44),Rect2(350,404,65,66),Rect2(475,390,88,18),Rect2(625,342,85,18),Rect2(760,285,55,185),Rect2(815,285,100,18)])

func _mutation(ok: bool) -> void:
    notice="Мутация применена" if ok else "Недоступно: занят, нет места или достигнут предел"
    notice_until=Time.get_ticks_msec()+1800
