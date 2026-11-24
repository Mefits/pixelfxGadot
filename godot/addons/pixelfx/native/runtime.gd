extends RefCounted
## Native equivalent of core/fx.js createFx for pure and stateful Godot modules.
## Module factory accepts options; implementation may expose update(dt), draw(p,t),
## draw_back(p,t). The owner shares one Painter across effects and actors.
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const ACTOR=preload("res://addons/pixelfx/native/actor.gd")
const FADE: float=.3
var meta: Dictionary
var options: Dictionary
var impl
var time: float=0
var stop_at: float=INF

func _init(module_meta: Dictionary,factory: Callable,overrides: Dictionary={}) -> void:
    meta=module_meta.duplicate(true)
    options=resolve_options(meta,overrides)
    impl=factory.call(options)

static func _ramp(v: Variant) -> bool:
    if not v is Array or v.is_empty():
        return false
    for c in v:
        if not (c is int or c is float or (c is String and c.begins_with("#") and c.length()>=4 and c.length()<=9)):
            return false
    return true

static func resolve_options(meta: Dictionary,o: Dictionary) -> Dictionary:
    var defaults: Dictionary=meta.get("options",{})
    var out: Dictionary=defaults.duplicate(true)
    out.merge(o,true)
    for k in defaults:
        if _ramp(defaults[k]) and _ramp(o.get(k)) and defaults[k].size()!=o[k].size():
            var colors: Array=PAL.fit(o[k],defaults[k].size())
            var strings: Array=[]
            for c in colors:
                strings.append(PAL.to_hex(c))
            out[k]=strings
    if meta.get("actor",0) and not out.get("actor"):
        out["actor"]=ACTOR.stock(2 if int(meta["actor"])==2 else 1)
    return out

func update(dt: float) -> void:
    if dt<0:
        return
    time+=dt
    if impl.has_method("update"):
        var n: int=maxi(1,int(ceil(dt*120-1e-9)))
        for _i in range(n):
            impl.update(dt/n)

func draw(p,layer: String="") -> void:
    p.reset()
    p.place(options.get("x",0),options.get("y",0),options.get("flip",false),options.get("angle",0))
    p.fade=1.0 if stop_at==INF else clampf(1-(time-stop_at)/FADE,0,1)
    p.light_k=options.get("light",1)
    var duration: float=meta.get("duration",1)
    var tt: float=fmod(time,duration) if meta.get("loop",false) else minf(time,duration)
    if layer!="front" and impl.has_method("draw_back"):
        p.layer="back"
        impl.draw_back(p,tt)
    if layer!="back":
        p.layer="front"
        impl.draw(p,tt)

func stop() -> void:
    if stop_at==INF:
        stop_at=time

func done() -> bool:
    return time-stop_at>=FADE or (not meta.get("loop",false) and time>=float(meta.get("duration",1)))
