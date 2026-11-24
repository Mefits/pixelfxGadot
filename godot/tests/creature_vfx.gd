extends SceneTree
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const PAINT=preload("res://addons/pixelfx/native/painter.gd")
var failures: int=0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _curves() -> void:
    var l: Dictionary=P.layer("sparks")
    l.duration=2.0
    l.curves={"size":[[0.0,2.0],[.25,20.0],[1.0,4.0]],"alpha":[[0.0,0.0],[.5,1.0],[1.0,0.0]],"speed":[[0.0,0.0],[.5,100.0],[1.0,0.0]],"glow":[[0.0,0.0],[1.0,1.0]]}
    var p: Dictionary={"schema":1,"name":"Curves","seed":12,"layers":[l]}
    check(P.valid(p),"Independent curves valid")
    check(is_equal_approx(P.value(l,"size",.125),11.0),"Piecewise sample")
    check(is_equal_approx(P.value(l,"size",1.0),4.0),"Last endpoint")
    check(is_equal_approx(P.value(l,"alpha",.75),.5),"Independent alpha")
    check(is_equal_approx(P.value(l,"glow",.4),.4),"Independent glow")
    check(is_equal_approx(P.speed_distance(l,.25),12.5),"Partial acceleration integral")
    check(is_equal_approx(P.speed_distance(l,.75),87.5),"Partial deceleration integral")
    check(is_equal_approx(P.speed_distance(l,1.0),100.0),"Full integral")
    for invalid in [[[0.0,0.0],[.5,1.0],[.5,0.0],[1.0,1.0]],[[.1,0.0],[1.0,1.0]],[[0.0,0.0],[1.0,2.0]]]:
        check(not P.valid_points("alpha",invalid),"Reject malformed curve")
    var broken: Dictionary=p.duplicate(true)
    broken.layers[0].curves["unknown"]=[[0.0,0.0],[1.0,1.0]]
    check(not P.valid(broken),"Reject unknown channel")
    check(P.save_preset(p,"user://test_independent_curves.json"),"Save curves")
    var loaded: Dictionary=P.load_preset("user://test_independent_curves.json")
    check(P.valid(loaded),"Load curves")
    if not loaded.is_empty():
        check(is_equal_approx(P.speed_distance(loaded.layers[0],.75),87.5),"Roundtrip integral")
    var paint=PAINT.new(240,160)
    var renderer=R.new()
    var anchors: Dictionary={"origin":Vector2(120,80)}
    renderer.render(paint,p,.7,anchors)
    var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
    renderer.render(paint,p,1.1,anchors)
    renderer.render(paint,p,.7,anchors)
    check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Curved backwards seek deterministic")
    var legacy: Dictionary={"schema":1,"name":"Legacy","seed":12,"layers":[P.layer("sparks")]}
    legacy.layers[0].curve="linear"
    var equivalent: Dictionary=legacy.duplicate(true)
    var copy: Dictionary=equivalent.layers[0]
    copy.curves={}
    for ch in P.CHANNELS:copy.curves[ch]=P.initial_points(copy,ch)
    for t in [.1,.3,.5]:
        renderer.render(paint,legacy,t,anchors)
        var baseline: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,equivalent,t,anchors)
        check(baseline==paint.rgba_bytes()+paint.rgba_bytes(true),"Legacy linear equivalent pixels")

func _streams() -> void:
    var l: Dictionary=P.layer("sparks")
    l.duration=1.0
    l.follow=false
    l.gravity=0.0
    l.emitter={"rate":4.0,"life":.6,"life_jitter":0.0,"shape":"point","radius":0.0}
    var p: Dictionary={"schema":1,"name":"Stream","seed":9,"layers":[l]}
    check(P.valid(p) and P.birth_count(l)==4,"Stream valid and bounded")
    check(is_equal_approx(P.duration(p),1.6),"Tail extends preset")
    var renderer=R.new()
    var paint=PAINT.new(240,160)
    var anchors: Dictionary={"origin":Vector2(100,80)}
    for spec in [[0.0,1],[.24,1],[.26,2],[.51,3],[.76,3],[1.09,2],[1.26,1],[1.36,0],[1.6,0]]:
        renderer.render(paint,p,float(spec[0]),anchors)
        check(renderer.particles==int(spec[1]),"Stream alive at "+str(spec[0]))
    check(paint.color.count(0)==paint.color.size() and paint.light.count(0)==paint.light.size(),"Stream expires")
    var visits: Array=[]
    var provider: Callable=func(_name:String,t:float)->Vector2:
        visits.append(t)
        return Vector2(80+t*20,80)
    renderer.render(paint,p,.76,{},128,provider)
    check(visits.has(.25) and visits.has(.5) and visits.has(.75),"World particles use birth anchors")
    visits.clear()
    l.follow=true
    renderer.render(paint,p,.76,{},128,provider)
    check(visits.size()==1 and is_equal_approx(float(visits[0]),.76),"Attached particles use current anchor")
    l.follow=false
    for shape in P.EMITTER_SHAPES:
        l.emitter.shape=shape
        l.emitter.radius=8.0
        l.emitter.life_jitter=.4
        renderer.render(paint,p,.81,anchors)
        var first: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,p,.2,anchors)
        renderer.render(paint,p,.81,anchors)
        check(first==paint.rgba_bytes()+paint.rgba_bytes(true),"Stream seek "+shape)
    check(P.save_preset(p,"user://test_stream_fx.json"),"Save stream")
    var loaded: Dictionary=P.load_preset("user://test_stream_fx.json")
    check(P.valid(loaded),"Load stream")
    if not loaded.is_empty():
        renderer.render(paint,p,.81,anchors)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,loaded,.81,anchors)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Stream roundtrip pixels")
    var invalid: Dictionary=p.duplicate(true)
    invalid.layers[0].emitter.rate=65
    check(not P.valid(invalid),"Reject over-budget rate")
    invalid.layers[0].emitter.rate=32
    invalid.layers[0].type="ring"
    check(not P.valid(invalid),"Reject emitter on non-particle primitive")
    check(P.valid(P.demo(4)),"Stream demo valid")

func _run() -> void:
    _curves()
    _streams()
    var renderer=R.new()
    var paint=PAINT.new(240,160)
    var anchors={"origin":Vector2(120,80),"hand":Vector2(83,76),"target":Vector2(166,76)}
    for i in range(4):
        var p: Dictionary=P.demo(i)
        check(P.valid(p),"Demo valid")
        for frame in range(1,12):
            var t: float=P.duration(p)*frame/12
            renderer.render(paint,p,t,anchors,128)
            var color: PackedByteArray=paint.rgba_bytes()
            var light: PackedByteArray=paint.rgba_bytes(true)
            renderer.render(paint,p,t,anchors,128)
            check(color==paint.rgba_bytes() and light==paint.rgba_bytes(true),"Deterministic seek")
            check(renderer.active_layers>0,"Active layers")
        renderer.render(paint,p,P.duration(p)+1,anchors,128)
        check(renderer.active_layers==0 and paint.color.count(0)==paint.color.size() and paint.light.count(0)==paint.light.size(),"Effect expires")
    var p: Dictionary=P.demo()
    check(P.save_preset(p,"user://test_composed_fx.json"),"Save")
    var loaded: Dictionary=P.load_preset("user://test_composed_fx.json")
    check(P.valid(loaded),"Loaded preset valid")
    if not loaded.is_empty():
        check(loaded.name==p.name and int(loaded.seed)==int(p.seed) and loaded.layers.size()==p.layers.size(),"Roundtrip metadata")
        for i in range(p.layers.size()):
            for key in p.layers[i]:
                var expected: Variant=p.layers[i][key]
                var actual: Variant=loaded.layers[i].get(key)
                if expected is int or expected is float:
                    check((actual is float or actual is int) and is_equal_approx(float(expected),float(actual)),"Roundtrip numeric "+key)
                else:check(actual==expected,"Roundtrip field "+key)
        for t in [.1,.25,.4,.6]:
            renderer.render(paint,p,t,anchors,128)
            var original: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
            renderer.render(paint,loaded,t,anchors,128)
            check(original==paint.rgba_bytes()+paint.rgba_bytes(true),"Roundtrip pixel equality")
    var ru: Dictionary=P.demo()
    ru.name="Молния синяя"
    check(P.filename(ru.name)=="Молния_синяя","Cyrillic filename")
    check(P.save_preset(ru),"Save Russian preset")
    check(P.load_preset(P.FOLDER.path_join("Молния_синяя.json")).get("name")=="Молния синяя","Russian name roundtrip")
    p.layers[0].duration=-1
    check(not P.valid(p),"Reject invalid data")
    var q: Dictionary={"schema":1,"name":"anchor","seed":1,"layers":[P.layer("glow")]}
    q.layers[0].anchor="hand"
    renderer.render(paint,q,.2,anchors)
    var before: PackedByteArray=paint.rgba_bytes()
    anchors.hand+=Vector2(20,0)
    renderer.render(paint,q,.2,anchors)
    check(before!=paint.rgba_bytes(),"Anchor follows")
    renderer.enable_acceleration()
    renderer.render(paint,P.demo(),.3,anchors,128)
    check(renderer.batch.accelerated_calls>0 and renderer.bolt.accelerated_calls>0,"Native PixelFX used")
    print("VFX composer tests failures: ",failures)
    quit(0 if failures==0 else 1)
