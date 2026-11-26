extends Node2D
const Cloth=preload("res://lab/secondary_motion_072.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Stance=preload("res://lab/body_weighted_057.gd")
var cloth=Cloth.new()
var base:Array=[]
var fixed_body:Array=[]
var raster
var sprite:Sprite2D
var overlay:Node2D
var status:Label
var speed_label:Label
var wind_slider:HSlider
var mass_slider:HSlider
var bend_slider:HSlider
var gust_toggle:CheckButton
var mesh_toggle:CheckButton
var direction:int=1
var manual:bool=false
var wind:float=0.
var gust:bool=false
var show_mesh:bool=false
var accum:float=0.
var physics_us:float=0.
var prep_us:float=0.
var raster_us:float=0.
var bridge_us:float=0.
var cloth_pixels:int=0
var anchor:Vector3
var rig
var failed:=""
const ORIGIN=Vector2(246,205)
const DENSITY=3.
# Packed colors AABBGGRR, as required by PixelFX.
const CFG={"width":480,"height":270,"origin":[246,205],"density":3,"ink":0xff000000,"outline":3,
    "light":[-.48,-.64,.6],"seams":false,"debug":true,"materials":[
    [0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],
    [0xffa09d74,0xff827d50,0xff656139,0xff4a4628],
    [0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],
    [0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
func _ready()->void:
    raster=ClassDB.instantiate("PixelFXBodyRaster")
    if raster==null:
        failed="Native extension unavailable"
        return
    rig=Body.make_rig()
    var pose:Dictionary=Stance.stance()
    rig.evaluate(pose)
    base=Body.new(2).make(rig.points,pose.angles,rig.rotations.head)
    fixed_body=base.duplicate(true)
    # Neutral adult test mannequin in a simple uniform. Material only;
    # deliberately independent of the Sasuke styling experiment.
    for i in [0,2,3,8,9]:base[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:base[i].material_id=2
    var neck:Dictionary=base[1].duplicate(true)
    var chest:Vector2=rig.points.chest
    var head:Vector2=rig.points.head
    var n:Vector2=chest.lerp(head,.36)
    anchor=Vector3(n.x+1.1,n.y,2.7)
    neck.sections=[[.04,2.32,2.32,2.23,0],[.19,2.36,2.36,2.27,0],[.37,2.12,2.12,2.15,0],[.48,1.82,1.82,1.89,0]]
    neck.part_id=20
    neck.material_id=3
    base.append(neck)
    cloth.collisions=[
        [Vector3(chest.x,chest.y+4.,0.),Vector3(4.8,7.8,3.35)],
        [Vector3(head.x,head.y,0.),Vector3(3.9,4.4,3.25)]]
    reset_cloth()
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    overlay=Node2D.new()
    add_child(overlay)
    overlay.draw.connect(_draw_cloth_debug)
    status=Label.new()
    status.position=Vector2(12,6)
    status.add_theme_font_size_override("font_size",13)
    add_child(status)
    speed_label=Label.new()
    speed_label.position=Vector2(12,23)
    speed_label.add_theme_font_size_override("font_size",10)
    add_child(speed_label)
    if not manual:make_controls()
    render_frame()
func make_controls()->void:
    var panel=VBoxContainer.new()
    panel.position=Vector2(8,211)
    panel.theme=Theme.new()
    panel.theme.default_font_size=11
    panel.size=Vector2(464,55)
    add_child(panel)
    var line=HBoxContainer.new()
    panel.add_child(line)
    var l=Label.new()
    l.text="Wind"
    line.add_child(l)
    wind_slider=HSlider.new()
    wind_slider.max_value=180.
    wind_slider.step=1.
    wind_slider.custom_minimum_size=Vector2(125,20)
    line.add_child(wind_slider)
    wind_slider.value_changed.connect(func(v):wind=v*direction)
    var reverse=Button.new()
    reverse.text="Reverse"
    line.add_child(reverse)
    reverse.pressed.connect(func():direction=-direction;wind=wind_slider.value*direction)
    gust_toggle=CheckButton.new()
    gust_toggle.text="Gust"
    line.add_child(gust_toggle)
    gust_toggle.toggled.connect(func(v):gust=v)
    mesh_toggle=CheckButton.new()
    mesh_toggle.text="Mesh"
    line.add_child(mesh_toggle)
    mesh_toggle.toggled.connect(func(v):show_mesh=v)
    var second=HBoxContainer.new()
    panel.add_child(second)
    var ml=Label.new()
    ml.text="Mass"
    second.add_child(ml)
    mass_slider=HSlider.new()
    mass_slider.min_value=.5
    mass_slider.max_value=3.
    mass_slider.step=.05
    mass_slider.value=1.
    mass_slider.custom_minimum_size=Vector2(100,18)
    second.add_child(mass_slider)
    mass_slider.value_changed.connect(func(v):cloth.mass=v)
    var bl=Label.new()
    bl.text="Bend"
    second.add_child(bl)
    bend_slider=HSlider.new()
    bend_slider.max_value=.05
    bend_slider.step=.001
    bend_slider.value=.01
    bend_slider.custom_minimum_size=Vector2(95,18)
    second.add_child(bend_slider)
    bend_slider.value_changed.connect(func(v):cloth.bend=v)
    var reset=Button.new()
    reset.text="Reset"
    second.add_child(reset)
    reset.pressed.connect(reset_cloth)
func reset_cloth()->void:
    cloth.reset(anchor)
    for j in 480:cloth.step(0.,false)
func _process(delta:float)->void:
    if manual or raster==null:return
    accum+=minf(delta,.10)
    while accum>=Cloth.DT:
        cloth.step(wind,gust)
        accum-=Cloth.DT
    render_frame()
func render_frame()->bool:
    var before:int=Time.get_ticks_usec()
    var parts:Array=base.duplicate(true)
    cloth.triangles(parts,3)
    prep_us=Time.get_ticks_usec()-before
    before=Time.get_ticks_usec()
    var result:Dictionary=raster.render(CFG,parts)
    if not result.get("ok",false):
        failed=str(result)
        return false
    raster_us=result.cpu_us
    bridge_us=Time.get_ticks_usec()-before-raster_us
    cloth_pixels=0
    for id in result.part:
        if id>20:cloth_pixels+=1
    var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    var bounds=im.get_used_rect()
    if bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=480 or bounds.end.y>=270:
        failed="Clipped geometry"
        return false
    if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
    else:sprite.texture.update(im)
    status.text="LAB 0.72   /   SCARF WIND TEST"
    speed_label.text="WIND %+04.0f   |   %s   |   mass %.2f   bend %.3f"%[wind,"GUSTS" if gust else "STEADY",cloth.mass,cloth.bend]
    queue_redraw()
    overlay.queue_redraw()
    return true
func _draw()->void:
    draw_rect(Rect2(0,0,480,270),Color("#263540"))
    for x in range(0,480,24):draw_line(Vector2(x,42),Vector2(x,210),Color("#30414d"),1.)
    for y in range(42,211,24):draw_line(Vector2(0,y),Vector2(480,y),Color("#30414d"),1.)
    draw_line(Vector2(8,210),Vector2(472,210),Color("#6b7d87"),1.)
    var f=Vector2(65 if wind>=0. else 415,121)
    draw_circle(f,28.,Color("#536876"))
    draw_circle(f,25.,Color("#22313c"))
    for j in 4:
        var a:float=j*PI*.5+cloth.time*wind*.10
        var points=PackedVector2Array([f,f+Vector2(18,5).rotated(a),f+Vector2(22,13).rotated(a),f+Vector2(6,10).rotated(a)])
        draw_colored_polygon(points,Color("#8195a0"))
    draw_circle(f,4.,Color("#b5c2c6"))
    draw_line(f+Vector2(0,28),Vector2(f.x,210),Color("#80909b"),3.)
    draw_line(Vector2(f.x-17,209),Vector2(f.x+17,209),Color("#80909b"),3.)
    if absf(wind)>1.:
        var s:float=signf(wind)
        for j in 5:
            var y:float=74.+j*22.
            for i in 5:
                var x:float=f.x+s*(36.+fmod(i*25.+cloth.time*absf(wind)*.75,125.))
                draw_line(Vector2(x,y),Vector2(x+s*12.,y),Color("#578c9f"),1.)
func _draw_cloth_debug()->void:
    if show_mesh:
        for edge in cloth.edges:
            if float(edge[3])<0.:continue
            var a:Vector3=cloth.nodes[edge[0]]
            var b:Vector3=cloth.nodes[edge[1]]
            overlay.draw_line(ORIGIN+Vector2(a.x,a.y)*DENSITY,ORIGIN+Vector2(b.x,b.y)*DENSITY,Color("#e2c87a"),1.)
