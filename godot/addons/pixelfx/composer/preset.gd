extends RefCounted
const TYPES=["lightning","sparks","glow","ring","slash","droplets","smoke"]
const ANCHORS=["origin","hand","target"]
const FOLDER="user://vfx_presets"
const CURVES=["linear","ease in","ease out","smooth"]
const MAX_LAYERS=12
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
    return true
static func duration(p: Dictionary) -> float:
    var d: float=.05
    for l in p.layers:
        if l.enabled:d=maxf(d,float(l.start)+float(l.duration))
    return d
static func curve(u: float,kind: String) -> float:
    u=clampf(u,0,1)
    match kind:
        "ease in":return u*u
        "ease out":return 1-(1-u)*(1-u)
        "smooth":return u*u*(3-2*u)
    return u
static func filename(name: String) -> String:
    var clean: String=""
    for ch in name:
        if ch.is_valid_identifier() or ch.is_valid_int() or ch in ["-"," "]:clean+=ch
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
