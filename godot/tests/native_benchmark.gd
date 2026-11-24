extends SceneTree
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")
const LIGHTNING=preload("res://addons/pixelfx/native/lightning.gd")
const PS=preload("res://addons/pixelfx/native/particles.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var p=PAINTER.new(160,112)
    p.place(20,56)
    var l=LIGHTNING.new()
    var c: Array=PAL.fit(LIGHTNING.VOLT,8)
    var rng=RNG.new(301)
    var ps=PS.new(312)
    var ms: Array[float]=[]
    for f in range(140):
        var start: int=Time.get_ticks_usec()
        p.clear()
        var bolt: Array=LIGHTNING.zigzag(rng,0,0,100,-12,0.27,0.7)
        l.stroke(p,bolt,0.85,c,0.85)
        for j in range(4):
            ps.spawn(PS.SPARK,30,-10,rng.between(-100,100),rng.between(-140,80),0.35)
        ps.advance(1.0/30.0)
        ps.draw(p)
        # Include CPU buffer-to-RGBA conversion, not GPU upload.
        var _color: PackedByteArray=p.rgba_bytes()
        var _light: PackedByteArray=p.rgba_bytes(true)
        if f>=20:
            ms.append((Time.get_ticks_usec()-start)/1000.0)
    ms.sort()
    print("Native CPU 160x112, 1 bolt + steady sparks, 120 measured frames: p50=",ms[59]," p95=",ms[113]," p99=",ms[118]," max=",ms[-1]," ms; GPU upload excluded")
    quit(0)
