extends SceneTree
const FX=preload("res://addons/pixelfx/effects/ball_lightning.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var fx=FX.new()
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    if cpp and not fx.enable_acceleration():
        quit(1)
        return
    var p=P.new(FX.SIZE.x,FX.SIZE.y)
    p.place(FX.PIVOT.x,FX.PIVOT.y)
    var golden:=FileAccess.get_file_as_bytes("res://tests/fixtures/ball.bin")
    var bytes_per: int=FX.SIZE.x*FX.SIZE.y*4
    if golden.size()!=120*bytes_per*2:
        quit(1)
        return
    var bad: int=0
    var times: Array[float]=[]
    for i in range(120):
        var start: int=Time.get_ticks_usec()
        p.clear()
        fx.draw(p,float(i)/30.0)
        times.append((Time.get_ticks_usec()-start)/1000.0)
        var ca: PackedByteArray=p.rgba_bytes()
        var li: PackedByteArray=p.rgba_bytes(true)
        var frame_bad: int=0
        for j in range(0,bytes_per,4):
            if ca.decode_u32(j)!=golden.decode_u32(i*bytes_per*2+j):
                frame_bad+=1
            if li.decode_u32(j)!=golden.decode_u32(i*bytes_per*2+bytes_per+j):
                frame_bad+=1
        if frame_bad>0:
            print("Ball frame ",i," mismatched packed pixels: ",frame_bad)
        bad+=frame_bad
    times.sort()
    print("Ball original parity: 120 frames; ",bad," mismatched packed pixels; p95 ",times[113]," ms; backend ", "C++" if cpp else "GDScript")
    print("Ball accelerated calls ",fx.lightning.accelerated_calls," batch ",fx.batch.accelerated_calls)
    if cpp and (fx.lightning.accelerated_calls==0 or fx.batch.accelerated_calls==0 or fx.lightning.rejected_calls!=0 or fx.batch.rejected_calls!=0):
        bad+=1
    quit(0 if bad==0 else 1)
