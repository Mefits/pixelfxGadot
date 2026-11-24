extends Node2D
const WORLD=preload("res://game/world.gd")
const M=preload("res://game/motor.gd")
var world=WORLD.new()
var paused:bool=false
var debug:bool=false
var single_player:bool=true
var hud:Label
var toolbar:HBoxContainer
var pause_button:Button
func _ready()->void:
    var theme0:=Theme.new()
    theme0.default_font_size=16
    toolbar=HBoxContainer.new()
    toolbar.position=Vector2(24,16)
    toolbar.theme=theme0
    toolbar.add_theme_constant_override("separation",8)
    add_child(toolbar)
    pause_button=_button("Пауза [Space]",_pause)
    _button("Сброс [R]",_reset)
    _button("Скелет [F1]",func():debug=not debug;queue_redraw())
    _button("Игрок 2 [F2]",_toggle_second)
    hud=Label.new()
    hud.position=Vector2(24,490)
    hud.add_theme_font_size_override("font_size",15)
    add_child(hud)
    _hud()
func _button(label:String,callback:Callable)->Button:
    var b:=Button.new()
    b.text=label
    b.focus_mode=Control.FOCUS_NONE
    b.custom_minimum_size.y=34
    toolbar.add_child(b)
    b.pressed.connect(callback)
    return b
func _pause()->void:
    paused=not paused
    pause_button.text="Пуск [Space]" if paused else "Пауза [Space]"
    _hud()
func _reset()->void:
    world=WORLD.new()
    queue_redraw()
    _hud()
func _toggle_second()->void:
    single_player=not single_player
    _hud()
func _unhandled_key_input(e:InputEvent)->void:
    if not e is InputEventKey or not e.pressed or e.echo:return
    match e.physical_keycode:
        KEY_SPACE:_pause()
        KEY_R:_reset()
        KEY_F1:debug=not debug;queue_redraw()
        KEY_F2:_toggle_second()
func _held(key:Key)->bool:return Input.is_physical_key_pressed(key)
func _physics_process(dt:float)->void:
    if paused:return
    var left:Dictionary={"move":float(_held(KEY_D))-float(_held(KEY_A)),"jump":_held(KEY_W),"run":_held(KEY_SHIFT)}
    var right:Dictionary={} if single_player else {"move":float(_held(KEY_RIGHT))-float(_held(KEY_LEFT)),"jump":_held(KEY_UP),"run":_held(KEY_CTRL)}
    world.advance(dt,left,right)
    _hud()
    queue_redraw()
func _hud()->void:
    hud.text="A/D — движение · W — прыжок · Shift — бег   |   "+("P2: неподвижен (F2)" if single_player else "P2: ←/→ · ↑ · Ctrl")+"\nN  /  0.02  /  Боевая стойка   |   "+("ПАУЗА" if paused else ("120 Гц · кадр "+str(world.ticks)))
func _segment(a:Vector2,b:Vector2,width:float,c:Color)->void:
    draw_line(a,b,Color("#17202b"),width+3,true)
    draw_line(a,b,c,width,true)
    draw_circle(b,width*.44,c,true)
func _limbs(p:Dictionary,side:String,c:Color,face:int)->void:
    _segment(p["thigh_"+side],p["knee_"+side],13,c.darkened(.15))
    _segment(p["knee_"+side],p["foot_"+side],10,c)
    var foot:Vector2=p["foot_"+side]
    draw_line(foot-Vector2(5*face,0),foot+Vector2(9*face,0),Color("#151c28"),6,true)
    _segment(p["shoulder_"+side],p["elbow_"+side],10,c)
    _segment(p["elbow_"+side],p["hand_"+side],8,c.lightened(.14))
    draw_circle(p["hand_"+side],6,Color("#17202b"))
    draw_circle(p["hand_"+side],4.6,c.lightened(.24))
func _fighter(m,r,c:Color)->void:
    var p:Dictionary=r.points
    draw_set_transform(Vector2(m.pos.x,M.FLOOR+3),0,Vector2(1,.19))
    draw_circle(Vector2.ZERO,25,Color(0,0,0,.24))
    draw_set_transform(Vector2.ZERO)
    _limbs(p,"far",c.darkened(.38),m.facing)
    var hips:Vector2=p.hips
    var chest:Vector2=p.chest
    var normal:Vector2=(chest-hips).normalized().orthogonal()
    draw_colored_polygon(PackedVector2Array([chest-normal*11,chest+normal*11,hips+normal*8,hips-normal*8]),Color("#182331"))
    draw_colored_polygon(PackedVector2Array([chest-normal*9,chest+normal*9,hips+normal*6,hips-normal*6]),c.darkened(.07))
    draw_line(hips-normal*7,hips+normal*7,Color("#29323b"),5,true)
    _limbs(p,"near",c,m.facing)
    _segment(chest,p.head,9,c.darkened(.2))
    draw_circle(p.head,13,Color("#17202b"))
    draw_circle(p.head,11,c.lightened(.34))
    var eye:Vector2=p.head+Vector2(5*m.facing,-2)
    draw_line(eye,eye+Vector2(4*m.facing,0),Color("#202633"),2)
    if debug:
        for key in p:draw_circle(p[key],2.6,Color("#f3d38a"))
        if m.grounded:
            for i in range(2):
                draw_circle(m.feet[i],4,Color("#d9b16a") if m.swing==i else Color("#78d7a2"))
                draw_line(m.feet[i],p["foot_near" if i==0 else "foot_far"],Color("#a8d4c3"),1,true)
        draw_line(m.pos,m.pos+Vector2(25*m.facing,0),Color.WHITE,1,true)
func _draw()->void:
    draw_rect(Rect2(0,0,960,540),Color("#172632"))
    draw_rect(Rect2(0,65,960,365),Color("#213542"))
    for i in range(12):
        var x:float=80*i
        draw_line(Vector2(x,95),Vector2(x,430),Color("#2b414d"),1)
    draw_rect(Rect2(0,430,960,110),Color("#26323d"))
    draw_line(Vector2(0,430),Vector2(960,430),Color("#82968e"),2)
    for i in range(24):
        draw_line(Vector2(i*40,430),Vector2(i*40-40,478),Color("#394956"),1)
    _fighter(world.a,world.rig_a,Color("#6daac8"))
    _fighter(world.b,world.rig_b,Color("#c88b72"))
