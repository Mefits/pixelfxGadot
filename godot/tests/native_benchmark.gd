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
    var shape_ms: Array[float]=[]
    var ink_ms: Array[float]=[]
    var sparks_ms: Array[float]=[]
    var copy_ms: Array[float]=[]
    for f in range(140):
        var start: int=Time.get_ticks_usec()
        p.clear()
        var bolt: Array=LIGHTNING.zigzag(rng,0,0,100,-12,0.27,0.7)
        var shape_end: int=Time.get_ticks_usec()
        l.stroke(p,bolt,0.85,c,0.85)
        var ink_end: int=Time.get_ticks_usec()
        for j in range(4):
            ps.spawn(PS.SPARK,30,-10,rng.between(-100,100),rng.between(-140,80),0.35)
        ps.advance(1.0/30.0)
        ps.draw(p)
        var sparks_end: int=Time.get_ticks_usec()
        # Include CPU buffer-to-RGBA conversion, not GPU upload.
        var _color: PackedByteArray=p.rgba_bytes()
        var _light: PackedByteArray=p.rgba_bytes(true)
        if f>=20:
            var end: int=Time.get_ticks_usec()
            ms.append((end-start)/1000.0)
            shape_ms.append((shape_end-start)/1000.0)
            ink_ms.append((ink_end-shape_end)/1000.0)
            sparks_ms.append((sparks_end-ink_end)/1000.0)
            copy_ms.append((end-sparks_end)/1000.0)
    ms.sort()
    print("Native CPU 160x112, 1 bolt + steady sparks, 120 measured frames: p50=",ms[59]," p95=",ms[113]," p99=",ms[118]," max=",ms[-1]," ms; GPU upload excluded")
    for row in [["shape+clear",shape_ms],["ink+glow",ink_ms],["particles",sparks_ms],["buffer conversion",copy_ms]]:
        var times: Array=row[1]
        times.sort()
        print("Native stage ",row[0]," p95=",times[113]," ms")
    quit(0)
