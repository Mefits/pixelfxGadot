extends SceneTree
const R=preload("res://addons/pixelfx/original_runtime.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var a=R.new()
    var b=R.new()
    if not a.open() or not b.open() or not b.set_acceleration(true):
        push_error("Original acceleration unavailable")
        quit(1)
        return
    var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/original.json"))
    var bad:int=0
    var frames:int=0
    for c in cases:
        var opts:Dictionary={"x":c.x,"y":c.y}
        var ha:int=a.create(c.id,opts,c.mode)
        var hb:int=b.create(c.id,opts,c.mode)
        if ha==0 or hb==0:
            quit(1)
            return
        var p=P.new(int(c.w),int(c.h))
        var q=P.new(int(c.w),int(c.h))
        var at:int=0
        var ta:Array[float]=[]
        var tb:Array[float]=[]
        for f in c.frames:
            while at<int(f.index):
                if not a.update(ha,1.0/30.0) or not b.update(hb,1.0/30.0):
                    quit(1)
                    return
                at+=1
            p.clear()
            q.clear()
            var start:int=Time.get_ticks_usec()
            if not a.draw(ha,p,"",c.mode=="act"):
                push_error(a.error)
                quit(1)
                return
            ta.append((Time.get_ticks_usec()-start)/1000.0)
            start=Time.get_ticks_usec()
            if not b.draw(hb,q,"",c.mode=="act"):
                push_error(b.error)
                quit(1)
                return
            tb.append((Time.get_ticks_usec()-start)/1000.0)
            if p.color!=q.color or p.light!=q.light:
                bad+=1
                print("Native host mismatch ",c.id," frame ",f.index)
            frames+=1
        ta.sort()
        tb.sort()
        print("Original Painter host ",c.id," ",c.mode," p95 ms: ",ta[mini(ta.size()-1,int(ta.size()*.95))]," -> ",tb[mini(tb.size()-1,int(tb.size()*.95))])
        a.destroy(ha)
        b.destroy(hb)
    var stats:Dictionary=b.acceleration_stats()
    print("Original Painter native calls: ",stats)
    if int(stats.get("calls",0))<100:
        bad+=1
    print("Original Painter host exact comparison: ",frames," frames; ",bad," failures")
    quit(0 if bad==0 else 1)
