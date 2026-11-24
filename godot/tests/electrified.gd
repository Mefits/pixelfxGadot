extends SceneTree
const FX=preload("res://addons/pixelfx/effects/electrified.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")
const A=preload("res://addons/pixelfx/native/actor.gd")
func _initialize() -> void:
    create_timer(20.0).timeout.connect(func(): quit(1))
    call_deferred("_run")
func _run() -> void:
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    var bytes: PackedByteArray=FileAccess.get_file_as_bytes("res://tests/fixtures/electrified.bin")
    var stride: int=108*92*4
    if bytes.size()!=120*stride*2:
        quit(1)
        return
    var bad: int=0
    var times: Array[float]=[]
    var index: int=0
    for k in [2,1]:
        var fx=FX.new({"actor":A.stock(k)})
        if cpp and not fx.enable_acceleration():
            quit(1)
            return
        var p=P.new(108,92)
        p.place(54,76)
        for i in range(60):
            p.clear()
            var start: int=Time.get_ticks_usec()
            fx.draw_back(p,float(i)/30)
            fx.draw(p,float(i)/30)
            times.append((Time.get_ticks_usec()-start)/1000.0)
            var ca: PackedByteArray=p.rgba_bytes()
            var li: PackedByteArray=p.rgba_bytes(true)
            var diff: int=0
            for j in range(0,stride,4):
                if ca.decode_u32(j)!=bytes.decode_u32(index*stride*2+j):
                    diff+=1
                if li.decode_u32(j)!=bytes.decode_u32(index*stride*2+stride+j):
                    diff+=1
            if diff:
                print("Electrified actor ",k," frame ",i,": ",diff," differences")
            bad+=diff
            index+=1
        if cpp and (fx.lightning.accelerated_calls==0 or fx.batch.accelerated_calls==0 or fx.lightning.rejected_calls!=0 or fx.batch.rejected_calls!=0):
            bad+=1
    times.sort()
    print("Electrified original parity: 120 frames, ",bad," differences; p95 ",times[113]," ms; ","C++" if cpp else "GDScript")
    quit(0 if bad==0 else 1)
