extends SceneTree
func _initialize():call_deferred("run")
func run():
    var stand=load("res://lab/walk_studio.tscn").instantiate()
    stand.manual=true
    root.add_child(stand)
    if not stand.last_ok:
        push_error("native body unavailable")
        quit(1)
        return
    var out:String=OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(out)
    # One complete actual T idle cycle, after the entry blend.
    var period:int=roundi(float(stand.walker.programs.walk_breathe.doc.duration)*60.)
    for i in period+stand.walker.STOP_TICKS+2:stand.walker.step(0)
    for i in range(0,period,2):
        stand.render_frame()
        if not stand.last_ok or stand.sprite.texture.get_image().save_png(out.path_join("%03d.png"%i))!=OK:
            push_error("capture failed")
            quit(1)
            return
        stand.walker.step(0)
        stand.walker.step(0)
    print("NATIVE_IDLE_CAPTURE_OK ",period)
    quit(0)
