extends SceneTree
const Scene=preload("res://lab/motion_stylization/studio.tscn")
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.is_empty():
        quit(2)
        return
    var folder:String=args[0]
    root.size=Vector2i(960,570)
    var s=Scene.instantiate()
    s.manual=true
    root.add_child(s)
    await process_frame
    if s.raster==null:
        quit(3)
        return
    for attack in ["punch","heel"]:
        var expected:Array=[]
        for mode in 6:
            s.reset()
            s.set_mode(mode)
            var started:bool=s.training.press(1) if attack=="punch" else s.training.press_kick()
            if not started:failures.append("attack start")
            var dir:String=folder+"/"+attack+"_"+str(mode)
            DirAccess.make_dir_recursive_absolute(dir)
            var trace:Array=[]
            for tick in 78:
                s.advance(false)
                if not s.last_ok:failures.append("raster error")
                trace.append([s.walker.pose.duplicate(true),s.walker.x,s.training.hits,s.training.misses,s.training.strikes,s.training.active,s.training.kick.age,s.training.kick.active,s.training.hit_flash])
                await process_frame
                await RenderingServer.frame_post_draw
                var im:Image=root.get_texture().get_image()
                if im.save_png(dir+"/%03d.png"%tick)!=OK:failures.append("save frame")
            if mode==0:expected=trace
            elif trace!=expected:failures.append("simulation diverged "+attack+" "+str(mode))
    print("MOTION_STYLIZATION_CAPTURE_V002 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
