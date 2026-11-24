extends SceneTree
const ED=preload("res://lab/pose_workshop.tscn")
const ARENA=preload("res://lab/combat_lab.tscn")
var failures: int=0
func _initialize() -> void:
    call_deferred("_run")
func check(v: bool,msg: String) -> void:
    if not v:failures+=1;push_error(msg)
func capture(path: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var img: Image=root.get_texture().get_image()
    check(img.save_png(path)==OK,"Screenshot save")
func _run() -> void:
    root.size=Vector2i(960,540)
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    var ed=ED.instantiate()
    root.add_child(ed)
    await process_frame
    ed._seek(.2)
    check(ed.pose.angles.has("shoulder_near"),"Editor sampled attack")
    var n: int=ed.bank.strike.keys.size()
    ed._seek(.17)
    ed.pose.angles["chest"]=20
    ed._key()
    check(ed.bank.strike.keys.size()==n+1,"Editor add key")
    ed._add_event()
    check(ed.bank.strike.events.size()==2,"Editor event insert")
    check(ed.event_kind.get_item_text(0)=="Удар" and ed.bank.strike.events[0].kind=="strike","Localized event retains stable ID")
    ed._seek(.2)
    ed._adjacent(-1)
    check(is_equal_approx(ed.time,.17),"Previous key exact")
    ed._adjacent(1)
    check(is_equal_approx(ed.time,.2),"Next key exact")
    ed._undo()
    check(ed.bank.strike.events.size()==1,"Undo event")
    ed._redo()
    check(ed.bank.strike.events.size()==2,"Redo event")
    ed._seek(.13)
    var old_pose: Dictionary=ed.pose.duplicate(true)
    ed.pose.root[0]=8
    ed._edit()
    check(ed.bank.strike.keys.size()==n+2 and is_equal_approx(float(ed.bank.strike.keys[2].pose.root[0]),8),"Auto key edit")
    ed._undo()
    check(ed.bank.strike.keys.size()==n+1,"Undo auto key")
    ed._seek(.2)
    await process_frame
    check(ed.fighter_select.get_global_rect().end.x<=960,"Fighter chooser inside viewport")
    check(ed.root_y.get_global_rect().end.x<=960,"Root controls inside viewport")
    await capture(dir.path_join("pose-workshop.png"))
    ed.dirty=false
    root.remove_child(ed)
    ed.queue_free()
    var arena=ARENA.instantiate()
    root.add_child(arena)
    await process_frame
    arena.set_physics_process(false)
    arena.world.a.pos.x=100
    arena.world.b.pos.x=180
    for i in range(28):
        arena.world.step(1.0/60,{"cast":i==0},{})
    arena.canvas.queue_redraw()
    arena._vfx()
    arena._update_hud()
    check(arena.world.b.hp==80,"Arena spell marker")
    check(arena.bolt.accelerated_calls>0,"Arena used PixelFX C++")
    await capture(dir.path_join("combat-lab.png"))
    print("Workshop interaction and actual GL preview failures: ",failures)
    quit(0 if failures==0 else 1)
