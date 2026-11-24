extends SceneTree
const FX=preload("res://addons/pixelfx/effects/custom/rift_collapse.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")
const MOTION=preload("res://addons/pixelfx/native/motion.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    var times: Array[float]=[]
    var fails: int=0
    var frames: int=0
    var report:=Image.create(192*7,128*3,false,Image.FORMAT_RGBA8)
    var sample_frames: Array=[4,10,15,17,20,26,37]
    for preset in range(3):
        var ref=FX.new(121,preset)
        var fast=FX.new(121,preset)
        if cpp and not fast.enable_acceleration():
            quit(1)
            return
        var a=P.new(FX.SIZE.x,FX.SIZE.y)
        var b=P.new(FX.SIZE.x,FX.SIZE.y)
        a.place(FX.PIVOT.x,FX.PIVOT.y)
        b.place(FX.PIVOT.x,FX.PIVOT.y)
        for i in range(51):
            var t: float=float(i)/30.0
            a.clear()
            b.clear()
            var start: int=Time.get_ticks_usec()
            fast.draw(b,t)
            times.append((Time.get_ticks_usec()-start)/1000.0)
            ref.draw(a,t)
            if a.color!=b.color or a.light!=b.light:
                print("Custom mismatch ",preset," frame ",i)
                fails+=1
            frames+=1
            if i in sample_frames:
                if a.color.count(0)==a.color.size():
                    fails+=1
                var tile:=Image.create(192,128,false,Image.FORMAT_RGBA8)
                for y in range(128):
                    for x in range(192):
                        var index: int=y*192+x
                        var c: int=a.color[index]&0xffffffff
                        var l: int=a.light[index]&0xffffffff
                        var alpha: float=float(c>>24)/255.0
                        var bg: Color=Color8(18,25,39)
                        var pixel:=Color8(
                            int(clampf((c&255)*alpha+bg.r*255*(1-alpha)+(l&255),0,255)),
                            int(clampf(((c>>8)&255)*alpha+bg.g*255*(1-alpha)+((l>>8)&255),0,255)),
                            int(clampf(((c>>16)&255)*alpha+bg.b*255*(1-alpha)+((l>>16)&255),0,255)))
                        tile.set_pixel(x,y,pixel)
                report.blit_rect(tile,Rect2i(0,0,192,128),Vector2i(sample_frames.find(i)*192,preset*128))
        # Rewind/seek must reproduce the same buffers after arbitrary previous frames.
        a.clear()
        b.clear()
        ref.draw(a,0.72)
        fast.draw(b,0.72)
        if a.color!=b.color or a.light!=b.light:
            fails+=1
        a.clear()
        ref.draw(a,FX.DURATION)
        if a.color.count(0)!=a.color.size() or a.light.count(0)!=a.light.size():
            fails+=1
        if cpp and (fast.lightning.accelerated_calls==0 or fast.batch.accelerated_calls==0 or fast.lightning.rejected_calls!=0 or fast.batch.rejected_calls!=0):
            fails+=1
    var pos: Array=MOTION.fly(1,2,3,4,2,5,0)
    if pos!=[7.0,20.0]:
        fails+=1
    times.sort()
    print("Custom Rift Collapse: ",frames," frames, failures ",fails," p95 ",times[int(ceil(times.size()*0.95))-1]," ms CPU; ", "C++" if cpp else "GDScript")
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    report.save_png(dir.path_join("rift-collapse-"+("cpp" if cpp else "gd")+".png"))
    quit(0 if fails==0 else 1)
