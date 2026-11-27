extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Profile=preload("res://lab/fighter_profile.gd")
const Studio=preload("res://lab/hybrid_studio.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
func _initialize()->void:call_deferred("record")
func record()->void:
    var out:=OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(out)
    var f=Training.new()
    var w=f.walker
    w.travel_limit=1000.
    w.x=-400.
    var body=Profile.make_body(w.profile)
    var raster=ClassDB.instantiate("PixelFXBodyRaster")
    if raster==null:
        quit(1)
        return
    for i in 18:f.step(1,true)
    var origin:float=w.x
    for tick in 72:
        if tick==16:f.press_jump(1)
        f.step(1,tick<16)
        var cfg:Dictionary=Studio.CFG.duplicate(true)
        cfg.width=620
        cfg.height=405
        cfg.origin=[roundi(80.+(w.x-origin)*3.),roundi(390.-f.jump.altitude*3.)]
        var parts:Array=body.make(w.rig.points,w.pose.angles,w.rig.rotations.head)
        Depth.apply(parts,clampf((absf(w.ground_speed)/60.-1.)/.85,0.,1.) if w.sprint_active else 0.)
        for i in [0,2,3,8,9]:parts[i].material_id=1
        for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
        var r:Dictionary=raster.render(cfg,parts)
        if not r.get("ok",false):
            quit(1)
            return
        var im:=Image.create_from_data(r.width,r.height,false,Image.FORMAT_RGBA8,r.rgba)
        if im.save_png(out.path_join("%03d.png"%tick))!=OK:
            quit(1)
            return
    quit()
