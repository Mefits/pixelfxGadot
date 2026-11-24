extends RefCounted
const TYPES=["lightning","sparks","glow","ring","slash","droplets","smoke"]
const ANCHORS=["origin","hand","target"]
const FOLDER="user://vfx_presets"
const CURVES=["linear","ease in","ease out","smooth"]
const MAX_LAYERS=12
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
    return l
static func demo(which: int=0) -> Dictionary:
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
        if l.has("curves"):
            if not l.curves is Dictionary:return false
            for channel in l.curves:
                if not CHANNELS.has(channel) or not valid_points(channel,l.curves[channel]):return false
    return true
static func duration(p: Dictionary) -> float:
    var d: float=.05
    for l in p.layers:
        d=maxf(d,float(l.start)+float(l.duration))
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
