extends SceneTree
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const PAINT=preload("res://addons/pixelfx/native/painter.gd")
const O=preload("res://addons/pixelfx/composer/organic.gd")
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

func _trails() -> void:
    var l: Dictionary=P.layer("trail")
    l.duration=1.0
    l.trail.life=.5
    l.trail.rate=32.0
    var p: Dictionary={"schema":1,"name":"Trail","seed":71,"layers":[l]}
    check(P.valid(p) and is_equal_approx(P.duration(p),1.5),"Trail valid and duration")
    var times: Array=R.trail_times(l,.75)
    check(times.size()<=P.MAX_TRAIL_SEGMENTS+2 and is_equal_approx(float(times[0]),.25) and is_equal_approx(float(times[-1]),.75),"Bounded trail history")
    var tail: Array=R.trail_times(l,1.2)
    check(is_equal_approx(float(tail[-1]),1.0),"Trail stops sampling at shutoff")
    var renderer=R.new()
    var paint=PAINT.new(240,160)
    var provider: Callable=func(_name:String,t:float)->Vector2:
        return Vector2(40+t*100,70+sin(t*7)*15)
    for style in P.TRAIL_STYLES:
        l.trail.style=style
        renderer.render(paint,p,.8,{},128,provider)
        check(renderer.trail_segments>0 and paint.color.count(0)<paint.color.size(),"Visible trail "+style)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,p,1.1,{},128,provider)
        check(renderer.trail_segments>0,"Trail tail survives")
        renderer.render(paint,p,.8,{},128,provider)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Trail seek "+style)
    renderer.render(paint,p,1.51,{},128,provider)
    check(renderer.trail_segments==0 and paint.color.count(0)==paint.color.size(),"Trail expires")
    renderer.render(paint,p,.8,{"hand":Vector2(80,70)})
    check(renderer.trail_segments==0,"Static anchor no fake trail")
    var jump: Callable=func(_name:String,t:float)->Vector2:
        return Vector2(20 if t<.5 else 200,80)
    renderer.render(paint,p,.75,{},128,jump)
    check(renderer.trail_segments==0,"Teleport not connected")
    check(P.save_preset(p,"user://test_trail_fx.json"),"Save trail")
    var loaded: Dictionary=P.load_preset("user://test_trail_fx.json")
    check(P.valid(loaded),"Load trail")
    if not loaded.is_empty():
        renderer.render(paint,p,.8,{},128,provider)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,loaded,.8,{},128,provider)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Trail roundtrip pixels")
    var invalid: Dictionary=p.duplicate(true)
    invalid.layers[0].trail.rate=65
    check(not P.valid(invalid),"Reject trail sample rate")
    check(P.valid(P.demo(5)),"Trail demo valid")

func _organics() -> void:
    var p: Dictionary=P.demo(6)
    check(P.valid(p),"Organic demo valid")
    var l: Dictionary=p.layers[0]
    var base:=Vector2(80,80)
    var target:=Vector2(160,80)
    var a: PackedVector2Array=O.centerline(l,base,target,.2,0,17)
    var b: PackedVector2Array=O.centerline(l,base,target,.7,0,17)
    check(a[0]==base and b[0]==base and a!=b,"Root fixed, wave changes")
    check(a.size()<=P.MAX_ORGANIC_SEGMENTS+1,"Bounded centerline")
    check(a==O.centerline(l,base,target,.2,0,17),"Deterministic geometry")
    var mass: Dictionary=p.layers[1]
    var axes_a: Vector2=O.mass_axes(mass,15.0,0.0)
    var axes_b: Vector2=O.mass_axes(mass,15.0,.2)
    check(axes_a!=axes_b and axes_b.x>0 and axes_b.y>0,"Pulsating mass")
    var renderer=R.new()
    var paint=PAINT.new(240,160)
    var anchors: Dictionary={"hand":base,"target":target}
    for kind in P.ORGANIC_TYPES:
        var q: Dictionary={"schema":1,"name":kind,"seed":31,"layers":[P.layer(kind)]}
        renderer.render(paint,q,.5,anchors)
        check(renderer.organic_segments>0 and paint.color.count(0)<paint.color.size(),"Visible "+kind)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,q,1.1,anchors)
        check(pixels!=paint.rgba_bytes()+paint.rgba_bytes(true),"Organic changes over time")
        renderer.render(paint,q,.5,anchors)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Organic reverse seek")
        renderer.render(paint,q,2.1,anchors)
        check(renderer.organic_segments==0 and paint.color.count(0)==paint.color.size(),"Organic expires")
    check(P.save_preset(p,"user://test_organic_fx.json"),"Save organics")
    var loaded: Dictionary=P.load_preset("user://test_organic_fx.json")
    check(P.valid(loaded),"Load organics")
    if not loaded.is_empty():
        renderer.render(paint,p,.8,anchors)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,loaded,.8,anchors)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Organic roundtrip pixels")
    var invalid: Dictionary=p.duplicate(true)
    invalid.layers[0].organic.arms=9
    check(not P.valid(invalid),"Reject excess arms")
    invalid.layers[0].organic.arms=3
    invalid.layers[0].organic.stretch=1.0
    check(not P.valid(invalid),"Reject singular stretch")

func _fields() -> void:
    var renderer=R.new()
    var paint=PAINT.new(240,160)
    var anchors: Dictionary={"origin":Vector2(120,80),"hand":Vector2(80,70),"target":Vector2(170,85)}
    for i in range(P.FIELD_TYPES.size()):
        var p: Dictionary=P.demo(i+7)
        var l: Dictionary=p.layers[0]
        var kind: String=P.FIELD_TYPES[i]
        check(P.valid(p) and l.type==kind,"Field preset "+kind)
        var at: float=float(l.duration)*.4
        renderer.render(paint,p,at,anchors)
        check(renderer.field_segments>0 and paint.color.count(0)<paint.color.size(),"Field visible "+kind)
        var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
        renderer.render(paint,p,float(l.duration)*.7,anchors)
        check(pixels!=paint.rgba_bytes()+paint.rgba_bytes(true),"Field changes "+kind)
        renderer.render(paint,p,at,anchors)
        check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Field seek "+kind)
        check(P.save_preset(p,"user://field_"+kind+".json"),"Field save "+kind)
        var loaded: Dictionary=P.load_preset("user://field_"+kind+".json")
        check(P.valid(loaded),"Field load "+kind)
        if not loaded.is_empty():
            renderer.render(paint,loaded,at,anchors)
            check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Field roundtrip "+kind)
        renderer.render(paint,p,float(l.duration)+.01,anchors)
        check(renderer.field_segments==0 and paint.color.count(0)==paint.color.size(),"Field expires "+kind)
        var invalid: Dictionary=p.duplicate(true)
        invalid.layers[0].field.thickness=13.0
        check(not P.valid(invalid),"Field rejects invalid width "+kind)
    var legacy: Dictionary=P.demo()
    check(P.valid(legacy),"Legacy remains valid")

func _bindings() -> void:
    var bindings=preload("res://addons/creature/vfx_bindings.gd")
    var runtime=preload("res://addons/creature/vfx_runtime.gd")
    var clips=preload("res://addons/creature/clips.gd")
    var combat=preload("res://addons/creature/combat.gd")
    var layer: Dictionary=P.layer("glow")
    layer.duration=.5
    var preset0: Dictionary={"schema":1,"name":"Integration","seed":19,"layers":[layer]}
    var bank: Dictionary={"strike":preset0,"kick":preset0}
    check(bindings.valid(bank),"Binding validates")
    check(not bindings.valid({"unknown":preset0}),"Unknown binding rejected")
    check(bindings.save_bank(bank,"user://test_creature_bindings.json"),"Save binding")
    var loaded: Dictionary=bindings.load_bank("user://test_creature_bindings.json")
    check(bindings.valid(loaded) and loaded.has("strike"),"Load binding")
    var fx=runtime.new(loaded)
    check(not fx.spawn("cast",null,"",Vector2(80,70),Vector2(100,70),1),"Missing role falls back")
    check(fx.spawn("strike",null,"",Vector2(80,70),Vector2(100,70),-1),"Spawn custom")
    check(runtime.sample(fx.active[0],"target",0)==Vector2(-20,0),"Mirrored local target")
    var paint=PAINT.new(240,160)
    paint.dot(5,5,0xffffffff)
    fx.draw(paint,128.0)
    check(paint.color[5*240+5]!=0,"Append preserves earlier pixels")
    for i in range(75):fx.advance()
    check(fx.active.is_empty(),"Instance expires")
    var w=combat.new(clips.defaults())
    w.custom_vfx=runtime.new(bank)
    w.a.pos.x=100
    w.b.pos.x=125
    var vanilla=combat.new(clips.defaults())
    vanilla.a.pos.x=100
    vanilla.b.pos.x=125
    var saw_custom: bool=false
    var frozen: bool=false
    for i in range(100):
        var input: Dictionary={"kick":i==0}
        var age_before: float=-1
        if w.hitstop>0 and not w.custom_vfx.active.is_empty():
            age_before=float(w.custom_vfx.active[0].age)
        w.step(combat.DT,input,{})
        vanilla.step(combat.DT,input,{})
        if not w.custom_vfx.active.is_empty():
            saw_custom=true
            check(w.custom_vfx.active[0].anchor=="foot_near","Kick uses authored limb")
            if age_before>=0:
                check(is_equal_approx(float(w.custom_vfx.active[0].age),age_before),"Freeze custom VFX")
                frozen=true
    check(saw_custom and frozen and w.hits==vanilla.hits and w.b.hp==vanilla.b.hp,"Visual binding does not alter combat")
    print("Binding integration checks complete")

func _marker_integration() -> void:
    var C=preload("res://addons/creature/clips.gd")
    var W=preload("res://addons/creature/combat.gd")
    var FX=preload("res://addons/creature/vfx_runtime.gd")
    var bank: Dictionary=C.defaults()
    var p: Dictionary=P.demo(8)
    var event: Dictionary={"t":.08,"kind":"vfx","anchor":"hand_far","preset":p.duplicate(true)}
    bank.strike.events.append(event)
    bank.strike.events.append({"t":.19,"kind":"vfx","anchor":"foot_near","preset":P.demo(7)})
    check(C.valid(bank),"Embedded VFX valid")
    check(C.save_bank(bank,"user://test_vfx_markers.json"),"Save clip markers")
    var loaded: Dictionary=C.load_bank("user://test_vfx_markers.json")
    check(loaded.strike.events.size()==3 and loaded.strike.events[1].preset==p,"Embedded preset survives save")
    var invalid: Dictionary=bank.duplicate(true)
    invalid.strike.events[1].preset.layers[0].size=-2
    check(not C.valid(invalid),"Reject invalid embedded preset")
    var w=W.new(loaded)
    w.custom_vfx=FX.new()
    var vanilla=W.new(C.defaults())
    for world in [w,vanilla]:
        world.a.pos.x=100
        world.b.pos.x=125
    var hand_seen: bool=false
    var foot_seen: bool=false
    for i in range(100):
        var input: Dictionary={"strike":i==0}
        w.step(W.DT,input,{})
        vanilla.step(W.DT,input,{})
        for item in w.custom_vfx.active:
            if item.anchor=="hand_far":hand_seen=true
            if item.anchor=="foot_near":foot_seen=true
    check(hand_seen and foot_seen,"Independent visual cues on two joints")
    check(w.hits==vanilla.hits and w.b.hp==vanilla.b.hp,"Visual cues do not add damage")
    var loop_clip: Dictionary=bank.walk.duplicate(true)
    loop_clip.events=[{"t":0.0,"kind":"vfx","anchor":"foot_near","preset":p},{"t":.3,"kind":"vfx","anchor":"foot_far","preset":p}]
    check(C.visual_events_between(loop_clip,-.000001,.01).size()==1,"Start cue fires once")
    check(C.visual_events_between(loop_clip,.59,.61).size()==1,"Loop boundary cue")
    check(C.visual_events_between(loop_clip,.61,.62).is_empty(),"No repeated boundary")
    check(C.visual_events_between(loop_clip,.61,.62,false).is_empty(),"Nonloop cue does not repeat")

func _preview_and_quick() -> void:
    var C=preload("res://addons/creature/clips.gd")
    var V=preload("res://addons/creature/vfx_preview.gd")
    var Q=preload("res://addons/pixelfx/composer/quick_adjust.gd")
    var clip: Dictionary=C.defaults().strike
    var p: Dictionary=P.demo(5)
    clip.events.append({"t":.05,"kind":"vfx","anchor":"hand_near","preset":p})
    var view=V.new()
    var paint=PAINT.new(144,108)
    var origin:=Vector2(72,84)
    var target:=Vector2(112,58)
    view.draw(paint,clip,.18,origin,target)
    check(view.active==1 and paint.color.count(0)<paint.color.size(),"Animation preview visible")
    var pixels: PackedByteArray=paint.rgba_bytes()+paint.rgba_bytes(true)
    view.draw(paint,clip,.3,origin,target)
    check(pixels!=paint.rgba_bytes()+paint.rgba_bytes(true),"Preview tracks pose time")
    view.draw(paint,clip,.18,origin,target)
    check(pixels==paint.rgba_bytes()+paint.rgba_bytes(true),"Reverse scrub deterministic")
    view.draw(paint,clip,0,origin,target)
    check(view.active==0 and paint.color.count(0)==paint.color.size(),"Before cue empty")
    view.draw(paint,clip,4,origin,target)
    check(view.active==0,"Preview effect expires")
    for i in range(12):
        var source: Dictionary=P.demo(i)
        var snapshot: Dictionary=source.duplicate(true)
        check(Q.scaled(source,1,1,1,0)==source,"Identity quick transform")
        var changed: Dictionary=Q.scaled(source,1.5,1.25,1.5,90)
        check(P.valid(changed) and source==snapshot,"Quick transform preserves source and schema")
        check(changed.layers.size()==source.layers.size(),"Quick retains layer count")
        check(float(changed.layers[0].size)>=float(source.layers[0].size),"Quick scales size")
        check(P.valid(Q.scaled(source,2,2,2,-180)),"Quick limits")
    var curve_p: Dictionary=P.demo(6)
    var changed: Dictionary=Q.scaled(curve_p,1,.5,1,0)
    check(is_equal_approx(float(changed.layers[0].curves.alpha[1][1]),.5),"Quick scales custom opacity curve")

func _run() -> void:
    _preview_and_quick()
    _marker_integration()
    _bindings()
    _fields()
    _organics()
    _trails()
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
