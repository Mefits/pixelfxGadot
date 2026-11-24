extends SceneTree
const FX=preload("res://addons/pixelfx/effects/chain_lightning.gd")
const RUN=preload("res://addons/pixelfx/native/runtime.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    var fx=RUN.new(FX.META,func(o): return FX.new(o),{"x":40,"y":82})
    if cpp and not fx.impl.enable_acceleration():
        quit(1)
        return
    var p=P.new(248,104)
    var bytes: PackedByteArray=FileAccess.get_file_as_bytes("res://tests/fixtures/chain.bin")
    var stride: int=248*104*4
    if bytes.size()!=54*stride*2:
        quit(1)
        return
    var bad: int=0
    var times: Array[float]=[]
    for i in range(54):
        p.clear()
        var start: int=Time.get_ticks_usec()
        fx.draw(p)
        times.append((Time.get_ticks_usec()-start)/1000.0)
        var ca: PackedByteArray=p.rgba_bytes()
        var li: PackedByteArray=p.rgba_bytes(true)
        var frame_bad: int=0
        for j in range(0,stride,4):
            if ca.decode_u32(j)!=bytes.decode_u32(i*stride*2+j):
                frame_bad+=1
            if li.decode_u32(j)!=bytes.decode_u32(i*stride*2+stride+j):
                frame_bad+=1
        if frame_bad:
            print("Chain frame ",i," differences ",frame_bad)
        bad+=frame_bad
        fx.update(1.0/30.0)
    times.sort()
    print("Chain original parity: 54 frames; ",bad," differing packed pixels; p95 ",times[51]," ms; ", "C++" if cpp else "GDScript")
    if cpp and (fx.impl.lightning.accelerated_calls==0 or fx.impl.batch.accelerated_calls==0 or fx.impl.lightning.rejected_calls!=0 or fx.impl.batch.rejected_calls!=0):
        bad+=1
    quit(0 if bad==0 else 1)
