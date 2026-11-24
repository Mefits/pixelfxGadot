extends SceneTree
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var c: Array=PAL.fit(L.VOLT,8)
    var fast=L.new()
    if not fast.enable_acceleration():
        push_error("Required C++ backend unavailable")
        quit(1)
        return
    var ref=L.new()
    var rng=RNG.new(9001)
    var a=PAINTER.new(256,160,-8,-6)
    var b=PAINTER.new(256,160,-8,-6)
    # Test layered strokes, clipping, mirroring, rotation, fades, power thresholds,
    # partial leader and hero frames, additive saturation, and nonempty buffers.
    for i in range(32):
        a.clear()
        b.clear()
        var angle: float=rng.between(-0.7,0.7)
        var mirror: bool=i%2==0
        var x: float=12.0 if not mirror else 220.0
        var y: float=rng.between(0,155)
        var alpha: float=rng.between(.2,1.0)
        var gain: float=rng.between(.3,1.2)
        for p in [a,b]:
            p.place(x,y,mirror,angle)
            p.fade=alpha
            p.light_k=gain
            p.glow(4,5,17,c[5],.7)
            p.line(-6,0,25,8,c[4],.8)
        var paths: Array=L.zigzag(rng,-5,0,80+i,-13,.27,.8)
        var k: float=[.25,.35,.49,.51,.6,.61,.85,1.0][i%8]
        var opts: Dictionary={"a":.75,"light":.8,"hero":i%3==0,"core":1.1 if i%4==0 else 0.0,"upTo":.58 if i%5==0 else 1.0}
        if i%3==0:
            opts["minY"]=-7.0
        ref.stroke(a,paths,k,c,.85,opts)
        fast.stroke(b,paths,k,c,.85,opts)
        ref.crackle(a,paths,k,c,.4,.8)
        fast.crackle(b,paths,k,c,.4,.8)
        if a.color!=b.color or a.light!=b.light:
            push_error("C++ raster mismatch at case "+str(i))
            quit(1)
            return
    print("C++ layered parity: 32/32; calls ",fast.accelerated_calls," rejected ",fast.rejected_calls)
    if fast.accelerated_calls!=64 or fast.rejected_calls!=0:
        quit(1)
        return
    for count in [1,4,8,16]:
        var frame=PAINTER.new(320,180)
        var timings: Array[float]=[]
        var geometry: Array=[]
        var r=RNG.new(310)
        for i in range(count):
            geometry.append(L.zigzag(r,0,0,90,-14,.27,.7))
        for i in range(110):
            var start: int=Time.get_ticks_usec()
            frame.clear()
            for j in range(count):
                frame.place(20+(j%3)*100,25+(j%4)*43)
                fast.stroke(frame,geometry[j],.85,c,.85)
            var _color: PackedByteArray=frame.rgba_bytes()
            var _light: PackedByteArray=frame.rgba_bytes(true)
            if i>=10:
                timings.append((Time.get_ticks_usec()-start)/1000.0)
        timings.sort()
        print("C++ cached geometry stress ",count," bolts: p50=",timings[49]," p95=",timings[94]," p99=",timings[98]," max=",timings[99]," ms; CPU only")
    quit(0 if fast.rejected_calls==0 else 1)
