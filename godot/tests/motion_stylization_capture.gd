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
    var stats:Dictionary={}
    for attack in ["punch","heel"]:
        var expected:Array=[]
        stats[attack]={}
        for mode in 7:
            s.reset()
            s.set_mode(mode)
            var started:bool=s.training.press(1) if attack=="punch" else s.training.press_kick()
            if not started:failures.append("attack start")
            var dir:String=folder+"/"+attack+"_"+str(mode)
            DirAccess.make_dir_recursive_absolute(dir)
            var trace:Array=[]
            var active_mesh:int=0
            var peak_parts:int=0
            var peak_extension:float=0.
            var offset_ticks:int=0
            var timing:Array=[]
            var onset_ticks:int=0
            for tick in 78:
                s.advance(false)
                if not s.last_ok:failures.append("raster error")
                if s.drive.phase:
                    timing.append({"tick":tick,"age":s.drive.tick,"speed":s.drive.velocity.length(),"acceleration":s.drive.acceleration,"score":s.drive.score,"onset":s.drive.onset_tick})
                if mode==2 and s.drive.trail().size()>1:onset_ticks+=1
                if mode in [3,4,5,6] and s.directed.changed:
                    active_mesh+=1
                    peak_extension=maxf(peak_extension,s.directed.extension)
                    if mode==6 and s.directed.surface.offset_segments().size()>0:offset_ticks+=1
                if not s.drive.phase and (s.directed.changed or not s.drive.trail().is_empty()):failures.append("effect outside phase")
                if attack=="heel" and s.training.kick.active and s.training.kick.age<=s.training.kick.chamber_tick and s.drive.phase:failures.append("kick chamber active")
                trace.append([s.walker.pose.duplicate(true),s.walker.x,s.training.hits,s.training.misses,s.training.strikes,s.training.active,s.training.kick.age,s.training.kick.active,s.training.hit_flash])
                await process_frame
                await RenderingServer.frame_post_draw
                var im:Image=root.get_texture().get_image()
                if im.save_png(dir+"/%03d.png"%tick)!=OK:failures.append("save frame")
            stats[attack][str(mode)]={"mesh_ticks":active_mesh,"extra_parts":peak_parts,"peak_extension":peak_extension,"offset_ticks":offset_ticks,"onset_ticks":onset_ticks,"timing":timing}
            if mode==2 and onset_ticks==0:failures.append("no onset trail "+attack)
            if mode in [3,4,5,6] and active_mesh==0:failures.append("no actual smear "+attack+" "+str(mode))
            if mode==0:expected=trace
            elif trace!=expected:failures.append("simulation diverged "+attack+" "+str(mode))
    var log=FileAccess.open(folder+"/../geometry_metrics.json",FileAccess.WRITE)
    if log!=null:log.store_string(JSON.stringify(stats))
    print("MOTION_STYLIZATION_CAPTURE_V005 ",JSON.stringify({"failures":failures,"geometry":stats}))
    quit(0 if failures.is_empty() else 1)
