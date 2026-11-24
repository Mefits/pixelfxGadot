extends SceneTree
const R=preload("res://addons/pixelfx/original_runtime.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var r=R.new()
    if not r.open():
        push_error(r.error)
        quit(1)
        return
    var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/original_catalog.json"))
    var ids: Array=[]
    for e in r.entries:
        ids.append(e.id)
    if ids!=manifest.effects or ids.size()<200:
        push_error("Incomplete original catalog")
        quit(1)
        return
    var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/original.json"))
    var bytes:=FileAccess.get_file_as_bytes("res://tests/fixtures/original.bin")
    var offset:int=0
    var differences:int=0
    var frames:int=0
    var bad:int=0
    var max_error:int=0
    var times:Array[float]=[]
    for c in cases:
        var h:int=r.create(c.id,{"x":c.x,"y":c.y},c.mode)
        if h==0:
            push_error(r.error)
            quit(1)
            return
        var p=P.new(int(c.w),int(c.h))
        var at:int=0
        for f in c.frames:
            while at<int(f.index):
                if not r.update(h,1.0/30.0):
                    push_error(r.error)
                    quit(1)
                    return
                at+=1
            p.clear()
            var start:int=Time.get_ticks_usec()
            if not r.draw(h,p,"",c.mode=="act"):
                push_error(r.error)
                quit(1)
                return
            times.append((Time.get_ticks_usec()-start)/1000.0)
            var n:int=int(c.w)*int(c.h)*4
            var local_diff:int=0
            for light in [false,true]:
                var actual:PackedByteArray=p.rgba_bytes(light)
                for j in range(n):
                    var d:int=absi(int(actual[j])-int(bytes[offset+j]))
                    if d>0:
                        local_diff+=1
                        max_error=maxi(max_error,d)
                offset+=n
            differences+=local_diff
            frames+=1
            var state:Dictionary=r.state(h)
            if state.is_empty() or absf(float(state.t)-float(f.t))>0.000001 or state.done!=f.done or state.frozen!=f.frozen or state.shake!=f.shake:
                bad+=1
            if local_diff:
                print("Original parity ",c.id," ",c.mode," frame ",f.index,": ",local_diff," byte differences")
        r.destroy(h)
    if offset!=bytes.size():
        bad+=1
    times.sort()
    print("Original reference: ",frames," frames; ",differences," channel differences; max ",max_error,"; state failures ",bad,"; render p95 ",times[int(times.size()*0.95)]," ms")
    if differences!=0 or bad!=0:
        quit(1)
        return
    var passed:int=0
    var acts:int=0
    var smoke_max:float=0
    for e in r.entries:
        var m:Dictionary=e.meta
        var w:int=int(m.size[0])
        var h:int=int(m.size[1])
        var opts:Dictionary={"x":m.origin[0],"y":m.origin[1]}
        var handle:int=r.create(e.id,opts)
        var p=P.new(w,h)
        var start:int=Time.get_ticks_usec()
        if handle==0 or not r.draw(handle,p) or not r.update(handle,0.1):
            push_error("Catalog "+str(e.id)+": "+r.error)
            quit(1)
            return
        p.clear()
        if not r.draw(handle,p):
            push_error("Catalog "+str(e.id)+": "+r.error)
            quit(1)
            return
        smoke_max=maxf(smoke_max,(Time.get_ticks_usec()-start)/1000.0)
        r.destroy(handle)
        passed+=1
        if e.act:
            var timing:Variant=r.timing(e.id)
            var bounds:Dictionary=r.bounds(e.id)
            if timing==null or bounds.is_empty():
                push_error("Act metadata "+str(e.id))
                quit(1)
                return
            handle=r.create(e.id,opts,"act")
            p.clear()
            if handle==0 or not r.draw(handle,p,"",true):
                push_error("Act "+str(e.id)+": "+r.error)
                quit(1)
                return
            r.destroy(handle)
            acts+=1
    var pose:Dictionary=r.pose({})
    if int(pose.get("n",0))<=0:
        push_error("Original rig unavailable")
        quit(1)
        return
    print("Original catalog smoke: ",passed," effects, ",acts," acts, worst two renders + update ",smoke_max," ms")
    quit(0)
