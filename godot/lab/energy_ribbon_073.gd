extends "res://lab/wind_room_072.gd"
# The same physical nodes drive the cloth and the original PixelFX
# stroke/crackle renderer. Only the electrical paths regenerate at 15Hz.
const Surface=preload("res://addons/pixelfx/native/surface.gd")
const Lightning=preload("res://addons/pixelfx/native/lightning.gd")
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const Palette=preload("res://addons/pixelfx/native/palette.gd")
var fx
var bolt
var colors:Array=[]
var effect_mode:int=1
var effect_us:int=0
var draw_calls:int=0
var paths:Array=[]
var last_shape_tick:int=-1
var local_paths:Array=[]
func _ready()->void:
    super._ready()
    if failed!="":return
    fx=Surface.new()
    add_child(fx)
    fx.configure(480,270)
    bolt=Lightning.new()
    if not bolt.enable_acceleration():
        failed="Native lightning unavailable"
        return
    colors=Palette.fit(Lightning.VOLT,8)
    if not manual:
        var b=Button.new()
        b.position=Vector2(373,6)
        b.text="FX mode"
        b.pressed.connect(func():effect_mode=(effect_mode+1)%3)
        add_child(b)
    render_frame()
# Build in cloth-local coordinates (s along arc, offset across), then
# reproject each point using current physical row centers on every frame.
# The random topology does not have to be regenerated at display rate.
func center(i:int)->Vector2:
    var v:Vector3=(cloth.nodes[2*i]+cloth.nodes[2*i+1])*.5
    return ORIGIN+Vector2(v.x,v.y)*DENSITY
func map_point(x:float,y:float)->Array:
    var t:float=clampf(x/(Cloth.DS*DENSITY),0.,float(Cloth.ROWS-1))
    var i:int=mini(int(floor(t)),Cloth.ROWS-2)
    var a:Vector2=center(i)
    var b:Vector2=center(i+1)
    var u:Vector2=(b-a).normalized()
    var p:Vector2=a.lerp(b,t-i)+Vector2(-u.y,u.x)*y
    return [p.x,p.y]
func render_frame()->bool:
    if not super.render_frame():return false
    if fx==null or bolt==null:return true
    var start:int=Time.get_ticks_usec()
    var p=fx.painter
    p.clear()
    if effect_mode!=0:
        var tick:int=int(floor(cloth.time*15.))
        if tick!=last_shape_tick:
            last_shape_tick=tick
            var r=RNG.new(RNG.hash32([77,tick]))
            var length:float=Cloth.DS*DENSITY*(Cloth.ROWS-1)
            local_paths=Lightning.zigzag(r,0.,0.,length,0.,.045,.44)
            # A shorter secondary discharge runs around the central ribbon.
            var sub=Lightning.zigzag(r,12.,-2.,length*.76,2.,.07,.28,.65)
            local_paths.append_array(sub)
        paths=Lightning.bend(local_paths,map_point)
        if effect_mode==1:
            bolt.stroke(p,paths,.84+.12*sin(cloth.time*23.),colors,.70,{"light":.42})
        else:
            bolt.crackle(p,paths,.90,colors,.58)
        draw_calls=bolt.accelerated_calls
    fx.present()
    effect_us=Time.get_ticks_usec()-start
    status.text="LAB 0.73   /   PHYSICAL ENERGY RIBBON"
    speed_label.text=["CLOTH ONLY","PIXELFX STROKE","PIXELFX CRACKLE"][effect_mode]+"   |   WIND %+04.0f   |   SIM 120 Hz / ARC 15 Hz"%wind
    return true
