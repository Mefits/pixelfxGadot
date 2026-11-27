extends "res://lab/walk_studio.gd"
const Stylizer=preload("res://lab/motion_stylization/stylizer.gd")
const Painter=preload("res://addons/pixelfx/native/painter.gd")
const Sweep=preload("res://lab/motion_stylization/swept_body.gd")
var sweep=Sweep.new()
const Seamless=preload("res://lab/motion_stylization/seamless_smear.gd")
var seamless=Seamless.new()
const MODES=["A · Original","B · Godot Trail Control","C · Seamless Smear","D · Surface Accent","E · Offset Trail","F · Multiples refined"]
var stylizer=Stylizer.new()
var mode:int=0
var choice:OptionButton
var intensity:HSlider
var threshold_control:HSlider
var trail_line:Line2D
var pixel_sprite:Sprite2D
var painter
var fx_status:Label
var repeat_choice:OptionButton
var repeat_clock:int=0

func _ready()->void:
    super._ready()
    trail_line=Line2D.new()
    trail_line.antialiased=false
    trail_line.joint_mode=Line2D.LINE_JOINT_ROUND
    add_child(trail_line)
    move_child(trail_line,sprite.get_index())
    pixel_sprite=Sprite2D.new()
    pixel_sprite.centered=false
    pixel_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(pixel_sprite)
    move_child(pixel_sprite,sprite.get_index())
    painter=Painter.new(480,270)
    var panel:=VBoxContainer.new()
    panel.position=Vector2(1510,145)
    panel.size=Vector2(345,300)
    panel.z_index=25
    add_child(panel)
    var heading:=Label.new()
    heading.text="MOTION STYLIZATION v0.04"
    panel.add_child(heading)
    choice=OptionButton.new()
    choice.focus_mode=Control.FOCUS_NONE
    for title in MODES:choice.add_item(title)
    panel.add_child(choice)
    choice.item_selected.connect(set_mode)
    var l:=Label.new()
    l.text="Интенсивность (0–150%)"
    panel.add_child(l)
    intensity=HSlider.new()
    intensity.min_value=0.
    intensity.max_value=1.5
    intensity.step=.05
    intensity.value=1.
    intensity.focus_mode=Control.FOCUS_NONE
    panel.add_child(intensity)
    intensity.value_changed.connect(func(v:float):
        stylizer.strength=v
        render_frame())
    var t:=Label.new()
    t.text="Порог скорости конечности"
    panel.add_child(t)
    threshold_control=HSlider.new()
    threshold_control.min_value=20.
    threshold_control.max_value=220.
    threshold_control.step=5.
    threshold_control.value=75.
    threshold_control.focus_mode=Control.FOCUS_NONE
    panel.add_child(threshold_control)
    threshold_control.value_changed.connect(func(v:float):
        stylizer.threshold=v
        render_frame())
    var sm:=Label.new()
    sm.text="Порог скорости смаза"
    panel.add_child(sm)
    var sm_slider:=HSlider.new()
    sm_slider.min_value=20.
    sm_slider.max_value=220.
    sm_slider.step=5.
    sm_slider.value=55.
    sm_slider.focus_mode=Control.FOCUS_NONE
    panel.add_child(sm_slider)
    sm_slider.value_changed.connect(func(v:float):
        stylizer.smear_threshold=v
        render_frame())
    repeat_choice=OptionButton.new()
    repeat_choice.focus_mode=Control.FOCUS_NONE
    for title in ["Автоповтор: выкл","Автоповтор: 1","Автоповтор: K"]:repeat_choice.add_item(title)
    panel.add_child(repeat_choice)
    repeat_choice.item_selected.connect(func(_i:int):repeat_clock=0)
    fx_status=Label.new()
    panel.add_child(fx_status)
    render_frame()

func reset()->void:
    stylizer.reset()
    sweep.reset()
    seamless.reset()
    repeat_clock=0
    if repeat_choice!=null:repeat_choice.select(0)
    super.reset()

func set_mode(value:int)->void:
    mode=clampi(value,0,5)
    if choice!=null:choice.select(mode)
    render_frame()

func advance(allow_repeat:bool=true)->void:
    if allow_repeat and repeat_choice!=null and repeat_choice.selected>0:
        if command()!=0 or training.jump.state!=0 or attack_repeat.enabled:
            repeat_choice.select(0)
        elif training.active==0 and not training.kick.active and not training.round_kick.active:
            if repeat_clock<=0:
                if repeat_choice.selected==1:training.press(1)
                else:training.press_kick()
                repeat_clock=36
            else:repeat_clock-=1
    super.advance(allow_repeat)

func visual_parts(parts:Array)->Array:
    var key:String=""
    var anchor:String=""
    var age:int=0
    var gate:bool=false
    var smear_gate:bool=false
    var accent:bool=false
    var world:=Vector2.ZERO
    if training.kick.active:
        var actor=training.kick
        key="K"
        age=actor.age
        anchor="foot_"+actor.side(actor.striking)
        world=actor.heel_tip(walker)
        gate=age>=maxi(1,actor.hit_tick-9) and age<=actor.hit_tick
        smear_gate=age>=maxi(1,actor.hit_tick-5) and age<actor.hit_tick
        accent=age==actor.hit_tick
    elif training.active!=0 and training.strike_anchor.begins_with("hand_"):
        key="1-"+str(training.active)
        age=training.age
        anchor=training.strike_anchor
        world=training.tip(anchor)
        var hit:int=ceili(float(training.binding.events[0].t)*60.)
        gate=training.preparation_age>=int(training.binding.prepare_ticks) and age>=maxi(1,hit-7) and age<=hit
        smear_gate=age>=maxi(1,hit-5) and age<hit
        accent=age==hit and training.preparation_age>=int(training.binding.prepare_ticks)
    var local:Vector2=world-Vector2.RIGHT*walker.x
    stylizer.sample(training.ticks,key,age,anchor,local,world,gate,smear_gate,accent)
    sweep.power=stylizer.strength
    sweep.speed_threshold=maxf(20.,stylizer.smear_threshold*.65)
    # Broader pre-impact window; no smear on the accent or recovery.
    sweep.sample(training.ticks,key,anchor,age,gate and not accent,accent,parts,walker.x,world)
    seamless.reset()
    var out:Array=parts
    if mode in [2,3,4]:out=seamless.build(parts,sweep)
    if mode==5:out=sweep.multiples(parts)
    if trail_line!=null:render_trail()
    return out

func visual_config()->Dictionary:
    if mode!=3 or not seamless.changed:return super.visual_config()
    var cfg:Dictionary=super.visual_config().duplicate(true)
    cfg.debug=true
    return cfg

func visual_image(im:Image,result:Dictionary)->Image:
    if mode==3:return seamless.paint_surface(im,result)
    return im

func render_trail()->void:
    trail_line.clear_points()
    trail_line.visible=mode==1
    pixel_sprite.visible=mode==4
    var points:Array[Dictionary]=stylizer.trail()
    if fx_status!=null:fx_status.text="Скорость %.0f · Смаз %.2f"%[stylizer.delta.length()*60.,sweep.envelope]
    if mode==4:
        render_offset()
        return
    if points.size()<2:
        pixel_sprite.hide()
        return
    if mode==1:
        var widths:=Curve.new()
        var gradient:=Gradient.new()
        var offsets:=PackedFloat32Array()
        var colors:=PackedColorArray()
        trail_line.width=12.3*view_scale
        var total:float=0.
        for i in range(1,points.size()):total+=Vector2(points[i-1].p).distance_to(Vector2(points[i].p))
        var traveled:float=0.
        for i in points.size():
            var s:Dictionary=points[i]
            if i>0:traveled+=Vector2(points[i-1].p).distance_to(Vector2(s.p))
            var u:float=clampf(traveled/maxf(.001,total),0.,1.)
            trail_line.add_point(ORIGIN+Vector2(s.p)*view_scale)
            widths.add_point(Vector2(u,clampf(float(s.width)/12.3,0.,1.)))
            offsets.append(u)
            colors.append(Color(.91,.79,.60,float(s.alpha)))
        gradient.offsets=offsets
        gradient.colors=colors
        trail_line.width_curve=widths
        trail_line.gradient=gradient
func render_offset()->void:
    var rows:Array[Dictionary]=seamless.offset_segments()
    if rows.is_empty():
        pixel_sprite.hide()
        return
    painter.clear()
    var origin:=Vector2(240,219)
    for row in rows:
        var a:Vector2=origin+Vector2(row.a)*3.
        var b:Vector2=origin+Vector2(row.b)*3.
        painter.beam(a.x,a.y,b.x,b.y,float(row.width)*3.,0xffa0d4ff,float(row.alpha))
    present_pixels()

func present_pixels()->void:
    var origin:=Vector2(240,219)
    var im:=Image.create_from_data(480,270,false,Image.FORMAT_RGBA8,painter.rgba_bytes())
    pixel_sprite.texture=ImageTexture.create_from_image(im)
    pixel_sprite.position=ORIGIN+Vector2(walker.x,-training.jump.altitude)*view_scale-origin*view_scale/3.
    pixel_sprite.scale=Vector2.ONE*view_scale/3.
