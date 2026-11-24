extends RefCounted
## Stateless-at-time evaluation using the existing PixelFX painter and bolt algorithms.
## Anchor provider signature: (name: String, time: float) -> Vector2.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const B=preload("res://addons/pixelfx/native/batch.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const R=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const O=preload("res://addons/pixelfx/composer/organic.gd")
var batch=B.new()
var bolt=L.new()
var accelerated: bool=false
var render_ms: float=0
var active_layers: int=0
var particles: int=0
var trail_segments: int=0
var organic_segments: int=0
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
    trail_segments=0
    organic_segments=0
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        var age: float=time-float(l.start)
        if not l.enabled or age<0 or age>=P.layer_duration(l):continue
        active_layers+=1
        if l.type=="trail":
            _trail(painter,l,time,R.hash32([int(preset.seed),i]),anchors,provider)
            continue
        if P.is_stream(l):
            _stream(painter,l,age,time,R.hash32([int(preset.seed),i]),anchors,floor_y,provider)
            continue
        var u: float=age/float(l.duration)
        var size: float=P.value(l,"size",u)
        var alpha: float=P.value(l,"alpha",u)
        var glow: float=P.value(l,"glow",u)
        var pos: Vector2=origin(l.anchor,time if l.follow else float(l.start),anchors,provider)+Vector2(l.x,l.y)
        var color: int=PAL.from_hex(l.color)
        var seed0: int=R.hash32([int(preset.seed),i])
        if l.type in P.ORGANIC_TYPES:
            var target: Vector2=origin("target",time if l.follow else float(l.start),anchors,provider)
            var draw_batch=batch.begin(painter)
            organic_segments+=O.draw(draw_batch,l,pos,target,age,size,alpha,glow,color,seed0)
            batch.finish()
            continue
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
# Sample history on an emission-relative time grid, including clipped endpoints.
static func trail_times(l: Dictionary,time: float) -> Array:
    var start: float=float(l.start)
    var end: float=start+float(l.duration)
    var life: float=float(l.trail.life)
    var lo: float=maxf(start,time-life)
    var hi: float=minf(time,end)
    if hi<=lo:return []
    var rate: float=float(l.trail.rate)
    var times: Array=[lo]
    var first: int=int(floor((lo-start)*rate))+1
    for j in range(first,first+P.MAX_TRAIL_SEGMENTS):
        var t: float=start+float(j)/rate
        if t>=hi-.000001:break
        if t>lo+.000001:times.append(t)
    times.append(hi)
    return times

func _trail(painter,l: Dictionary,time: float,seed0: int,anchors: Dictionary,provider: Callable) -> void:
    if not provider.is_valid():return
    var times: Array=trail_times(l,time)
    if times.size()<2:return
    var t: Dictionary=l.trail
    var life: float=float(t.life)
    var color: int=PAL.from_hex(l.color)
    var offset: Vector2=Vector2(l.x,l.y)
    var d=batch.begin(painter)
    var old: Vector2=origin(l.anchor,float(times[0]),anchors,provider)+offset
    for i in range(1,times.size()):
        var a_time: float=float(times[i-1])
        var b_time: float=float(times[i])
        var pos: Vector2=origin(l.anchor,b_time,anchors,provider)+offset
        var delta: Vector2=pos-old
        var dist: float=delta.length()
        if dist<.05 or dist>float(t.break_distance):
            old=pos
            continue
        trail_segments+=1
        var steps: int=clampi(int(ceil(dist/1.5)),1,32)
        var normal: Vector2=delta.normalized().orthogonal()
        var prev: Vector2=old
        for j in range(1,steps+1):
            var f: float=float(j)/steps
            var birth: float=lerpf(a_time,b_time,f)
            var u: float=clampf((time-birth)/life,0,1)
            var width: float=P.value(l,"size",u)
            var alpha: float=P.value(l,"alpha",u)
            var glow: float=P.value(l,"glow",u)
            var q: Vector2=old.lerp(pos,f)
            if t.style=="electric":
                var tick: int=int(floor((birth-float(l.start))*96.0+.00001))
                var rng=R.new(R.hash32([seed0,tick]))
                q+=normal*rng.between(-float(t.jitter),float(t.jitter))*(1-u)
            if alpha>.001:
                if t.style=="dots":
                    if j==steps:d.disc(q.x,q.y,maxf(.5,width*.5),color,alpha)
                else:
                    if width<=1.5:d.line(prev.x,prev.y,q.x,q.y,color,alpha)
                    else:d.disc(q.x,q.y,width*.5,color,alpha)
                if glow>.01 and j==steps:
                    d.glow(q.x,q.y,maxf(2,width*1.4),color,glow*alpha)
            prev=q
        old=pos
    batch.finish()

# Stream particles are evaluated directly from their birth index and current time.
# No mutable particle pool, no replay from frame zero, and bounded work per layer.
func _stream(painter,l: Dictionary,age: float,time: float,seed0: int,anchors: Dictionary,floor_y: float,provider: Callable) -> void:
    var e: Dictionary=l.emitter
    var rate: float=float(e.rate)
    var total: int=P.birth_count(l)
    var first: int=maxi(0,int(floor((age-P.max_particle_life(l))*rate)))
    var last: int=mini(total-1,int(floor(age*rate)))
    if first>last:return
    var d=batch.begin(painter)
    var color: int=PAL.from_hex(l.color)
    var current_origin: Vector2=origin(l.anchor,time,anchors,provider)+Vector2(l.x,l.y)
    for j in range(first,last+1):
        var birth: float=float(j)/rate
        var particle_age: float=age-birth
        var rng=R.new(R.hash32([seed0,j]))
        var life: float=float(e.life)*(1.0+rng.between(-float(e.life_jitter),float(e.life_jitter)))
        if particle_age<0 or particle_age>=life:continue
        var u: float=particle_age/life
        var angle: float=deg_to_rad(float(l.angle)+rng.between(-float(l.spread)*.5,float(l.spread)*.5))
        var factor: float=rng.between(.45,1.0)
        var rad: float=maxf(.5,P.value(l,"size",u)*rng.between(.55,1.0))
        var alpha: float=P.value(l,"alpha",u)
        var glow: float=P.value(l,"glow",u)
        var offset: Vector2=_spawn_offset(e,rng)
        var pos: Vector2=current_origin if l.follow else origin(l.anchor,float(l.start)+birth,anchors,provider)+Vector2(l.x,l.y)
        var travel: float=P.speed_distance(l,u)*life/float(l.duration)*factor
        var v: Vector2=Vector2.from_angle(angle)
        var q: Vector2=pos+offset+v*travel+Vector2(0,float(l.gravity)*particle_age*particle_age*.5)
        if l.collision and q.y>floor_y:q.y=floor_y-minf(8.0,(q.y-floor_y)*.3)
        particles+=1
        if l.type=="smoke":
            d.disc(q.x,q.y,rad,color,alpha*.6)
        elif l.type=="droplets":
            d.circle(q.x,q.y,rad,color,alpha)
        else:
            var end: Vector2=q-v*rad*2
            d.line(q.x,q.y,end.x,end.y,color,alpha)
        if glow>.01:d.glow(q.x,q.y,maxf(2,rad*2),color,glow*alpha)
    batch.finish()

static func _spawn_offset(e: Dictionary,rng) -> Vector2:
    var radius: float=float(e.radius)
    match e.shape:
        "disc":return Vector2.from_angle(rng.between(0,TAU))*sqrt(rng.next())*radius
        "ring":return Vector2.from_angle(rng.between(0,TAU))*radius
        "line":return Vector2(rng.between(-radius,radius),0)
    return Vector2.ZERO

static func _arc(d,pos: Vector2,radius: float,start: float,sweep: float,c: int,a: float) -> void:
    var n: int=clampi(int(absf(sweep)*radius*.6),8,160)
    var old: Vector2=pos+Vector2.from_angle(start)*radius
    for i in range(1,n+1):
        var q: Vector2=pos+Vector2.from_angle(start+sweep*float(i)/n)*radius
        d.line(old.x,old.y,q.x,q.y,c,a)
        old=q
