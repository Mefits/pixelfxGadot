extends RefCounted
const TYPES=["lightning","sparks","glow","ring","slash","droplets","smoke","trail","tendril","organic_mass"]
const ANCHORS=["origin","hand","target"]
const FOLDER="user://vfx_presets"
const CURVES=["linear","ease in","ease out","smooth"]
const MAX_LAYERS=12
const ORGANIC_TYPES=["tendril","organic_mass"]
const MAX_ORGANIC_ARMS=8
const MAX_ORGANIC_SEGMENTS=48
static func organic_defaults() -> Dictionary:
    return {"arms":3.0,"length":42.0,"wave":12.0,"frequency":1.5,"taper":.85,"pulse":.18,"stretch":.25,"aim":false}
static func valid_organic(o: Variant) -> bool:
    if not o is Dictionary or not o.get("aim") is bool:return false
    if not num(o.get("arms"),1,MAX_ORGANIC_ARMS) or float(o.arms)!=floorf(float(o.arms)):return false
    for spec in [["length",4,96],["wave",0,32],["frequency",0,6],["taper",0,1],["pulse",0,.45],["stretch",0,.65]]:
        if not num(o.get(spec[0]),spec[1],spec[2]):return false
    return true
static func organic_demo() -> Dictionary:
    var a: Dictionary=layer("tendril")
    a.duration=2.5
    a.organic.arms=4.0
    a.organic.length=58.0
    a.organic.aim=true
    a.curves={"alpha":[[0.0,0.0],[.12,1.0],[.8,1.0],[1.0,0.0]]}
    var b: Dictionary=layer("organic_mass")
    b.duration=2.5
    b.organic.pulse=.3
    b.curves=a.curves.duplicate(true)
    return {"schema":1,"name":"Живая ткань","seed":617,"layers":[a,b]}
const PARTICLE_TYPES=["sparks","droplets","smoke"]
const EMITTER_SHAPES=["point","disc","ring","line"]
const MAX_BIRTHS=320
static func emitter_defaults() -> Dictionary:
    return {"rate":32.0,"life":.65,"life_jitter":.2,"shape":"point","radius":8.0}
static func is_stream(l: Dictionary) -> bool:
    return l.type in PARTICLE_TYPES and l.has("emitter")
static func max_particle_life(l: Dictionary) -> float:
    return float(l.emitter.life)*(1.0+float(l.emitter.life_jitter))
const TRAIL_STYLES=["ribbon","electric","dots"]
const MAX_TRAIL_SEGMENTS=96
static func trail_defaults() -> Dictionary:
    return {"life":.55,"rate":48.0,"break_distance":40.0,"style":"ribbon","jitter":3.0}
static func valid_trail(t: Variant) -> bool:
    if not t is Dictionary or not t.get("style") in TRAIL_STYLES:return false
    if not num(t.get("rate"),8,64) or float(t.rate)!=floorf(float(t.rate)):return false
    return num(t.get("life"),.05,1.5) and num(t.get("break_distance"),4,120) and num(t.get("jitter"),0,12)
static func layer_duration(l: Dictionary) -> float:
    if is_stream(l):return float(l.duration)+max_particle_life(l)
    if l.type=="trail":return float(l.duration)+float(l.trail.life)
    return float(l.duration)
static func trail_demo() -> Dictionary:
    var a: Dictionary=layer("trail")
    a.duration=1.65
    a.trail.life=.7
    a.size=8.0
    a.end_size=.5
    a.color="#397fdd"
    a.glow=.45
    var b: Dictionary=layer("trail")
    b.duration=1.65
    b.trail.style="electric"
    b.trail.life=.45
    b.size=2.0
    b.end_size=.5
    b.color="#bceeff"
    b.glow=.75
    var c: Dictionary=layer("glow")
    c.anchor="hand"
    c.duration=1.65
    c.size=5.0
    c.end_size=5.0
    c.alpha=.8
    c.end_alpha=.8
    c.color="#8cddff"
    return {"schema":1,"name":"Электрический шлейф","seed":121,"layers":[a,b,c]}
static func valid_emitter(e: Variant) -> bool:
    if not e is Dictionary or not e.get("shape") in EMITTER_SHAPES:return false
    if not num(e.get("rate"),1,64) or float(e.rate)!=floorf(float(e.rate)):return false
    return num(e.get("life"),.05,3) and num(e.get("life_jitter"),0,.8) and num(e.get("radius"),0,40)
static func birth_count(l: Dictionary) -> int:
    return mini(MAX_BIRTHS,int(ceil(float(l.duration)*float(l.emitter.rate))))
static func stream_demo() -> Dictionary:
    var a: Dictionary=layer("sparks")
    a.anchor="hand"
    a.follow=false
    a.duration=1.6
    a.angle=0.0
    a.spread=24.0
    a.gravity=0.0
    a.color="#65dfff"
    a.size=3.0
    a.end_size=.5
    a.speed=85.0
    a.end_speed=18.0
    a.emitter={"rate":48.0,"life":.72,"life_jitter":.3,"shape":"disc","radius":4.0}
    a.curves={"alpha":[[0.0,.8],[.15,1.0],[1.0,0.0]],"glow":[[0.0,.8],[.5,.5],[1.0,0.0]]}
    var b: Dictionary=layer("smoke")
    b.anchor="hand"
    b.follow=false
    b.duration=1.6
    b.angle=0.0
    b.spread=25.0
    b.color="#526d8f"
    b.speed=38.0
    b.end_speed=12.0
    b.emitter={"rate":15.0,"life":1.1,"life_jitter":.25,"shape":"disc","radius":4.0}
    return {"schema":1,"name":"Поток энергии","seed":127,"layers":[b,a]}
const CHANNELS=["size","alpha","speed","glow"]
const RANGES={"size":[.5,80.0],"alpha":[0.0,1.0],"speed":[0.0,200.0],"glow":[0.0,1.0]}
const MAX_POINTS=16
const MIN_GAP=.001
static func layer(kind: String="sparks") -> Dictionary:
    var l={"type":kind,"enabled":true,"anchor":"origin","follow":true,"start":0.0,"duration":.65,"color":"#65caff","size":18.0,"end_size":32.0,"alpha":1.0,"end_alpha":0.0,"speed":65.0,"end_speed":65.0,"count":24,"spread":180.0,"angle":-90.0,"gravity":90.0,"glow":.35,"x":0.0,"y":0.0,"curve":"ease out","collision":false}
    match kind:
        "lightning": l.size=52.0;l.end_size=44.0;l.duration=.4;l.count=2;l.spread=40.0;l.angle=0.0
        "glow":l.size=12.0;l.end_size=28.0;l.glow=.9
        "ring":l.size=3.0;l.end_size=44.0
        "slash":l.size=18.0;l.end_size=36.0;l.duration=.26;l.angle=-20.0;l.spread=140.0
        "droplets":l.color="#a0e84b";l.size=2.0;l.end_size=1.0;l.gravity=150.0;l.collision=true;l.follow=false
        "smoke":l.color="#87919d";l.size=3.0;l.end_size=9.0;l.speed=18.0;l.end_speed=12.0;l.gravity=-10.0;l.glow=0.0;l.duration=1.4;l.alpha=.6;l.spread=65.0;l.follow=false
        "sparks":l.size=2.0;l.end_size=.5
        "trail":l.anchor="hand";l.duration=1.2;l.size=7.0;l.end_size=.5;l.follow=false;l.trail=trail_defaults()
    if kind in ORGANIC_TYPES:
        l.organic=organic_defaults()
        l.anchor="hand"
        l.duration=2.0
        l.size=8.0 if kind=="tendril" else 15.0
        l.end_size=4.0 if kind=="tendril" else 8.0
        l.color="#a84961" if kind=="tendril" else "#83354e"
        l.glow=0.0
        l.angle=0.0
        l.spread=90.0
    return l
static func demo(which: int=0) -> Dictionary:
    if which==4:return stream_demo()
    if which==5:return trail_demo()
    if which==6:return organic_demo()
    var layers: Array=[]
    var names=["Electric burst","Acid impact","Claw slash","Fire burst"]
    match which:
        1:
            var a=layer("droplets");a.anchor="target";a.angle=-90.0;a.spread=125.0
            var b=layer("smoke");b.anchor="target";b.color="#758f48";b.start=.15
            var c=layer("ring");c.anchor="target";c.color="#8ee24c";c.duration=.35
            layers=[a,b,c]
        2:
            var a=layer("slash");a.anchor="hand";a.color="#d4e8bd"
            var b=layer("sparks");b.anchor="target";b.start=.12;b.color="#e8b46c";b.count=12;b.follow=false
            layers=[a,b]
        3:
            var a=layer("glow");a.color="#ff7f27"
            var b=layer("sparks");b.color="#ffbc54";b.count=36;b.spread=300.0
            var c=layer("smoke");c.start=.13;c.color="#89716b"
            layers=[a,b,c]
        _:
            var a=layer("glow");a.anchor="hand";a.duration=.5
            var b=layer("lightning");b.anchor="hand";b.start=.12
            var c=layer("sparks");c.anchor="target";c.start=.24;c.follow=false
            var d=layer("ring");d.anchor="target";d.start=.24;d.duration=.38
            layers=[a,b,c,d]
    return {"schema":1,"name":names[clampi(which,0,3)],"seed":121,"layers":layers}
static func num(v: Variant,lo: float,hi: float) -> bool:
    return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi
static func valid(p: Variant) -> bool:
    if not p is Dictionary or p.get("schema")!=1 or not p.get("name") is String or not num(p.get("seed"),0,2147483647) or not p.get("layers") is Array:return false
    if p.layers.is_empty() or p.layers.size()>MAX_LAYERS:return false
    for l in p.layers:
        if not l is Dictionary or not l.get("type") in TYPES or not l.get("anchor") in ANCHORS or not l.get("curve") in CURVES:return false
        for k in ["enabled","follow","collision"]:
            if not l.get(k) is bool:return false
        if not l.get("color") is String or not Color.html_is_valid(l.color) or l.color.length()!=7:return false
        for spec in [["start",0,5],["duration",.05,5],["size",.5,80],["end_size",.5,80],["alpha",0,1],["end_alpha",0,1],["speed",0,200],["end_speed",0,200],["count",1,64],["spread",0,360],["angle",-180,180],["gravity",-200,300],["glow",0,1],["x",-100,100],["y",-100,100]]:
            if not num(l.get(spec[0]),spec[1],spec[2]):return false
        if float(l.start)+float(l.duration)>10:return false
        if l.has("emitter") and (not l.type in PARTICLE_TYPES or not valid_emitter(l.emitter)):return false
        if l.type=="trail":
            if not valid_trail(l.get("trail")):return false
        elif l.has("trail"):return false
        if l.type in ORGANIC_TYPES:
            if not valid_organic(l.get("organic")):return false
        elif l.has("organic"):return false
        if l.has("curves"):
            if not l.curves is Dictionary:return false
            for channel in l.curves:
                if not CHANNELS.has(channel) or not valid_points(channel,l.curves[channel]):return false
    return true
static func duration(p: Dictionary) -> float:
    var d: float=.05
    for l in p.layers:
        d=maxf(d,float(l.start)+layer_duration(l))
    return d
static func curve(u: float,kind: String) -> float:
    u=clampf(u,0,1)
    match kind:
        "ease in":return u*u
        "ease out":return 1-(1-u)*(1-u)
        "smooth":return u*u*(3-2*u)
    return u
# Optional independent absolute-value curves, normalized lifetime t in [0,1].
# Legacy presets remain schema 1 and keep their exact old sampling.
static func valid_points(channel: String,points: Variant) -> bool:
    if not RANGES.has(channel) or not points is Array:return false
    if points.size()<2 or points.size()>MAX_POINTS:return false
    var bounds: Array=RANGES[channel]
    var last: float=-1
    for pt in points:
        if not pt is Array or pt.size()!=2:return false
        if not num(pt[0],0,1) or not num(pt[1],bounds[0],bounds[1]):return false
        if float(pt[0])-last<MIN_GAP-0.00000001:return false
        last=float(pt[0])
    return float(points[0][0])==0.0 and float(points[-1][0])==1.0

static func has_curve(l: Dictionary,channel: String) -> bool:
    return l.has("curves") and l.curves.has(channel)

static func legacy_value(l: Dictionary,channel: String,u: float) -> float:
    if channel=="glow":return float(l.glow)
    var k: float=clampf(u,0,1) if channel=="speed" else curve(u,l.curve)
    return lerpf(float(l[channel]),float(l["end_"+channel]),k)

static func initial_points(l: Dictionary,channel: String) -> Array:
    var out: Array=[]
    # Approximate old easing at 1/8 intervals when enabling custom editing.
    var n: int=1 if channel in ["speed","glow"] or l.curve=="linear" else 8
    for i in range(n+1):
        var t: float=float(i)/n
        out.append([t,legacy_value(l,channel,t)])
    return out

static func sample_points(points: Array,u: float) -> float:
    u=clampf(u,0,1)
    for i in range(1,points.size()):
        var a: Array=points[i-1]
        var b: Array=points[i]
        if u<=float(b[0]):
            return lerpf(float(a[1]),float(b[1]),(u-float(a[0]))/(float(b[0])-float(a[0])))
    return float(points[-1][1])

static func value(l: Dictionary,channel: String,u: float) -> float:
    if has_curve(l,channel):return sample_points(l.curves[channel],u)
    return legacy_value(l,channel,u)

# Exact trapezoidal integration of the piecewise-linear velocity curve.
# Stateless and independent of frame rate, including backwards seeking.
static func speed_distance(l: Dictionary,u: float) -> float:
    u=clampf(u,0,1)
    var age: float=u*float(l.duration)
    if not has_curve(l,"speed"):
        return float(l.speed)*age+(float(l.end_speed)-float(l.speed))*age*u*.5
    var points: Array=l.curves.speed
    var integral: float=0
    for i in range(1,points.size()):
        var a: Array=points[i-1]
        var b: Array=points[i]
        var left: float=float(a[0])
        var right: float=minf(u,float(b[0]))
        if right<=left:break
        var v: float=lerpf(float(a[1]),float(b[1]),(right-left)/(float(b[0])-left))
        integral+=(right-left)*(float(a[1])+v)*.5
        if u<=float(b[0]):break
    return integral*float(l.duration)

static func filename(name: String) -> String:
    var clean: String=""
    for ch in name:
        var code: int=ch.unicode_at(0)
        if ch.is_valid_identifier() or ch.is_valid_int() or ch in ["-"," "] or (code>=0x0400 and code<=0x052f):clean+=ch
    clean=clean.strip_edges().replace(" ","_").left(60)
    return clean if not clean.is_empty() else "effect"
static func save_preset(p: Dictionary,path: String="") -> bool:
    if not valid(p):return false
    if path.is_empty():
        DirAccess.make_dir_recursive_absolute(FOLDER)
        path=FOLDER.path_join(filename(p.name)+".json")
    var f=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return false
    f.store_string(JSON.stringify(p,"  "))
    return true
static func load_preset(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var p: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    return p if valid(p) else {}
