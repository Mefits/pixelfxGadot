extends RefCounted
## Stateless-at-time evaluation using the existing PixelFX painter and bolt algorithms.
## Anchor provider signature: (name: String, time: float) -> Vector2.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const B=preload("res://addons/pixelfx/native/batch.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const R=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
var batch=B.new()
var bolt=L.new()
var accelerated: bool=false
var render_ms: float=0
var active_layers: int=0
var particles: int=0
func enable_acceleration(on: bool=true) -> bool:
    var a: bool=batch.enable_acceleration(on)
    var b: bool=bolt.enable_acceleration(on)
    accelerated=a and b
    return accelerated
func origin(name: String,t: float,anchors: Dictionary,provider: Callable) -> Vector2:
    if provider.is_valid():return provider.call(name,t)
    return anchors.get(name,anchors.get("origin",Vector2.ZERO))
func render(painter,preset: Dictionary,time: float,anchors: Dictionary={},floor_y: float=INF,provider: Callable=Callable()) -> void:
    var stamp: int=Time.get_ticks_usec()
    painter.clear()
    painter.place(0,0)
    painter.fade=1.0
    painter.light_k=1.0
    active_layers=0
    particles=0
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        var age: float=time-float(l.start)
        if not l.enabled or age<0 or age>=float(l.duration):continue
        active_layers+=1
        var u: float=age/float(l.duration)
        var size: float=P.value(l,"size",u)
        var alpha: float=P.value(l,"alpha",u)
        var glow: float=P.value(l,"glow",u)
        var pos: Vector2=origin(l.anchor,time if l.follow else float(l.start),anchors,provider)+Vector2(l.x,l.y)
        var color: int=PAL.from_hex(l.color)
        var seed0: int=R.hash32([int(preset.seed),i])
        if l.type=="lightning":
            var palette: Array=[]
            for j in range(8):palette.append(PAL.mix(PAL.scale_color(color,.15),PAL.mix(color,PAL.from_hex("#ffffff"),.85),float(j)/7))
            var rng=R.new(R.hash32([seed0,int(age*24)]))
            for j in range(mini(4,int(l.count))):
                var angle: float=deg_to_rad(float(l.angle)+rng.between(-float(l.spread)*.5,float(l.spread)*.5))
                var end: Vector2=pos+Vector2.from_angle(angle)*size
                bolt.stroke(painter,L.zigzag(rng,pos.x,pos.y,end.x,end.y,.18,.35),maxf(.03,alpha),palette,.7,{"light":glow,"a":alpha})
            continue
        var d=batch.begin(painter)
        match l.type:
            "glow":
                d.glow(pos.x,pos.y,size,color,glow*alpha)
                d.circle(pos.x,pos.y,maxf(.5,size*.13),PAL.mix(color,PAL.from_hex("#ffffff"),.65),alpha)
            "ring":
                _arc(d,pos,size,0,TAU,color,alpha)
                if glow>0:d.glow(pos.x,pos.y,size+4,color,glow*alpha*.4)
            "slash":
                var angle: float=deg_to_rad(float(l.angle))+u*.8
                var sweep: float=deg_to_rad(float(l.spread))
                _arc(d,pos,size,angle-sweep*.5,sweep,color,alpha)
                _arc(d,pos,maxf(.5,size-2),angle-sweep*.4,sweep*.8,PAL.mix(color,PAL.from_hex("#ffffff"),.7),alpha)
                if P.has_curve(l,"glow") and glow>.01:
                    d.glow(pos.x,pos.y,size,color,glow*alpha*.4)
            "sparks","droplets","smoke":
                var rng=R.new(seed0)
                var n: int=int(l.count)
                particles+=n
                # Evaluate distance once per layer, rather than once per particle.
                var travel: float=P.speed_distance(l,u) if P.has_curve(l,"speed") else (float(l.speed)*age+(float(l.end_speed)-float(l.speed))*age*u*.5)
                for j in range(n):
                    var angle: float=deg_to_rad(float(l.angle)+rng.between(-float(l.spread)*.5,float(l.spread)*.5))
                    var factor: float=rng.between(.45,1.0)
                    var distance: float=travel*factor
                    var q: Vector2=pos+Vector2.from_angle(angle)*distance+Vector2(0,float(l.gravity)*age*age*.5)
                    if l.collision and q.y>floor_y:q.y=floor_y-minf(8.0,(q.y-floor_y)*.3)
                    var rad: float=maxf(.5,size*rng.between(.55,1.0))
                    if l.type=="smoke":
                        d.disc(q.x,q.y,rad,color,alpha*.6)
                    elif l.type=="droplets":
                        d.circle(q.x,q.y,rad,color,alpha)
                    else:
                        var v: Vector2=Vector2.from_angle(angle)
                        var end: Vector2=q-v*rad*2
                        d.line(q.x,q.y,end.x,end.y,color,alpha)
                    if glow>.01:d.glow(q.x,q.y,maxf(2,rad*2),color,glow*alpha)
        batch.finish()
    render_ms=(Time.get_ticks_usec()-stamp)/1000.0
static func _arc(d,pos: Vector2,radius: float,start: float,sweep: float,c: int,a: float) -> void:
    var n: int=clampi(int(absf(sweep)*radius*.6),8,160)
    var old: Vector2=pos+Vector2.from_angle(start)*radius
    for i in range(1,n+1):
        var q: Vector2=pos+Vector2.from_angle(start+sweep*float(i)/n)*radius
        d.line(old.x,old.y,q.x,q.y,c,a)
        old=q
