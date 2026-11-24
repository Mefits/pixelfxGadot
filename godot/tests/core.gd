extends SceneTree
const M=preload("res://addons/pixelfx/native/math.gd")
const S=preload("res://addons/pixelfx/native/shapes.gd")
const A=preload("res://addons/pixelfx/native/actor.gd")
const R=preload("res://addons/pixelfx/native/rng.gd")
const MOTION=preload("res://addons/pixelfx/native/motion.gd")
const FX=preload("res://addons/pixelfx/native/runtime.gd")
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")
var failures: int=0

class Probe:
    extends RefCounted
    var steps: int=0
    var back_draws: int=0
    var front_draws: int=0
    func update(_dt: float) -> void:
        steps+=1
    func draw_back(p,_t: float) -> void:
        back_draws+=1
        p.px(0,0,0xffffffff)
    func draw(p,_t: float) -> void:
        front_draws+=1
        p.px(1,0,0xffffffff)

func _initialize() -> void:
    call_deferred("_run")

func _compare(a: Variant,b: Variant) -> void:
    if a is Array:
        if not b is Array or a.size()!=b.size():
            failures+=1
            return
        for i in range(a.size()):
            _compare(a[i],b[i])
    elif absf(float(a)-float(b))>1e-8:
        failures+=1

func _run() -> void:
    var d: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/core.json"))
    if not d is Dictionary:
        quit(1)
        return
    for v in d["values"]:
        var t: float=v[0]
        _compare([t,M.noise(t,31),M.noise2(t,t*.8,31),M.fbm(t,t*.8,31),M.tile_noise(t,t*.8,4,7,31),M.tile_fbm(t,t*.8,4,7,31),M.loop_noise(t,2,31)],v)
    for e in d["easings"]:
        var values: Array=[]
        for t in [0,.13,.49,.7,.99,1]:
            values.append(M.easing(e[0],t))
        _compare(values,e[1])
    var rng=R.new(101)
    var bolt: Array=S.bolt(rng,0,0,40,12)
    _compare(bolt,d["bolt"])
    _compare(S.forks(rng,bolt),d["forks"])
    var emissions: Array=[]
    MOTION.cycle(.8,1.2,12,44,func(r): return r.between(.1,.8),func(age: float,life: float,r,i: int): emissions.append([age,life,r.next(),i]))
    _compare(emissions,d["emissions"])
    for k in [1,2]:
        var a: Dictionary=A.stock(k)
        _compare(Array(a["mask"]["data"]),d["actors"][k-1]["data"])
        _compare(Array(a["pixels"]),d["actors"][k-1]["pixels"])
        _compare([a["x"],a["y"]],[d["actors"][k-1]["x"],d["actors"][k-1]["y"]])
    var fx=FX.new({"duration":2,"loop":true,"actor":2},func(_o): return Probe.new(),{"x":10,"y":10})
    fx.update(1.0/30)
    var p=PAINTER.new(24,24)
    fx.draw(p,"back")
    fx.draw(p,"front")
    if fx.impl.steps!=4 or fx.impl.back_draws!=1 or fx.impl.front_draws!=1 or p.get_color(0,0)==0 or p.get_color(1,0)==0 or fx.options["actor"]["w"]!=24:
        failures+=1
    fx.stop()
    fx.update(.31)
    if not fx.done():
        failures+=1
    print("Core math, shapes, emitter, actor and lifecycle failures: ",failures)
    quit(0 if failures==0 else 1)
