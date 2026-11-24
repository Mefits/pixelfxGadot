extends SceneTree
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const PAINT=preload("res://addons/pixelfx/native/painter.gd")
var failures: int=0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _run() -> void:
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
    check(P.load_preset("user://test_composed_fx.json")==p,"Roundtrip")
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
