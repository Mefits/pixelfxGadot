extends "res://lab/walk_studio.gd"
const Stylizer=preload("res://lab/motion_stylization/stylizer.gd")
const Painter=preload("res://addons/pixelfx/native/painter.gd")
const MODES=["A · Original","B · Godot Line2D","C · PixelFX Painter","D · Body Smear","E · Hybrid"]
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
    heading.text="MOTION STYLIZATION v0.01"
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
    intensity.value_changed.connect(func(v:float):stylizer.strength=v;render_frame())
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
    threshold_control.value_changed.connect(func(v:float):stylizer.threshold=v;render_frame())
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
    repeat_clock=0
    if repeat_choice!=null:repeat_choice.select(0)
    super.reset()

func set_mode(value:int)->void:
    mode=clampi(value,0,4)
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
    var world:=Vector2.ZERO
    if training.kick.active:
        var actor=training.kick
        key="K"
        age=actor.age
        anchor="foot_"+actor.side(actor.striking)
        world=actor.heel_tip(walker)
        gate=age>=maxi(1,actor.chamber_tick-1) and age<actor.hit_tick
    elif training.active!=0 and training.strike_anchor.begins_with("hand_"):
        key="1-"+str(training.active)
        age=training.age
        anchor=training.strike_anchor
        world=training.tip(anchor)
        var hit:int=ceili(float(training.binding.events[0].t)*60.)
        gate=training.preparation_age>=int(training.binding.prepare_ticks) and age>=maxi(1,hit-7) and age<hit
    var local:Vector2=world-Vector2.RIGHT*walker.x
    stylizer.sample(training.ticks,key,age,anchor,local,world,gate)
    if trail_line!=null:render_trail()
    if mode in [3,4]:return stylizer.deform(parts)
    return parts

func render_trail()->void:
    trail_line.clear_points()
    trail_line.visible=mode==1
    pixel_sprite.visible=mode in [2,4]
    var points:Array[Dictionary]=stylizer.trail()
    if fx_status!=null:fx_status.text="Скорость %.0f · Смаз %.2f"%[stylizer.delta.length()*60.,stylizer.weight]
    if points.size()<2:
        pixel_sprite.hide()
        return
    if mode==1:
        var widths:=Curve.new()
        var gradient:=Gradient.new()
        var offsets:=PackedFloat32Array()
        var colors:=PackedColorArray()
        trail_line.width=6.3*view_scale
        for i in points.size():
            var s:Dictionary=points[i]
            var u:float=float(i)/float(points.size()-1)
            trail_line.add_point(ORIGIN+Vector2(s.p)*view_scale)
            widths.add_point(Vector2(u,clampf(float(s.width)/6.3,0.,1.)))
            offsets.append(u)
            colors.append(Color(.91,.79,.60,float(s.alpha)))
        gradient.offsets=offsets
        gradient.colors=colors
        trail_line.width_curve=widths
        trail_line.gradient=gradient
    elif mode in [2,4]:
        painter.clear()
        var origin:=Vector2(240,219)
        for i in range(1,points.size()):
            var a:Dictionary=points[i-1]
            var b:Dictionary=points[i]
            var pa:Vector2=origin+(Vector2(a.p)-Vector2.RIGHT*walker.x)*3.
            var pb:Vector2=origin+(Vector2(b.p)-Vector2.RIGHT*walker.x)*3.
            var count:int=clampi(ceili(pa.distance_to(pb)),1,120)
            for j in range(count+1):
                var u:float=float(j)/count
                var p:Vector2=pa.lerp(pb,u)
                var width:float=lerpf(float(a.width),float(b.width),u)*3.
                var alpha:float=lerpf(float(a.alpha),float(b.alpha),u)
                painter.circle(p.x,p.y,maxf(.35,width*.5),0xff99c9e8,alpha)
        var im:=Image.create_from_data(480,270,false,Image.FORMAT_RGBA8,painter.rgba_bytes())
        pixel_sprite.texture=ImageTexture.create_from_image(im)
        pixel_sprite.position=ORIGIN+Vector2(walker.x,-training.jump.altitude)*view_scale-origin*view_scale/3.
        pixel_sprite.scale=Vector2.ONE*view_scale/3.
