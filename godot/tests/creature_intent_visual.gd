extends SceneTree
const LAB=preload("res://lab/physics_lab.tscn")
const PANEL=preload("res://lab/intent_panel.gd")
const TRACK=preload("res://addons/creature/motion_track.gd")
var failures: int=0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func capture(path: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(path)==OK,"Capture")
func _run() -> void:
    root.size=Vector2i(960,540)
    var lab=LAB.instantiate()
    root.add_child(lab)
    await process_frame
    lab.set_physics_process(false)
    lab.course=2
    lab._set_course()
    lab._reset()
    var c=lab.creature
    for i in range(120):c.advance(1.0/60,0,false)
    check(c.change_legs(true) and c.change_reach(.2) and c.change_tail(1),"Live anatomy in scene")
    var p: Vector2=c.body.point("front")
    lab.dummy.p=p+Vector2(44,-3)
    lab.dummy.r=14.0
    var ed=PANEL.new(c)
    lab.ui_layer.add_child(ed)
    await process_frame
    await process_frame
    check(ed.get_global_rect().end.x<=960 and ed.get_global_rect().end.y<=482,"Editor fits screen")
    ed.chosen=2
    ed._refresh()
    ed.fields.speed.value=180
    check(float(ed.draft.keys[2].speed)==180,"Edit key speed")
    ed._insert()
    check(ed.draft.keys.size()==7 and TRACK.valid(ed.draft),"Add key")
    ed._remove()
    check(ed.draft.keys.size()==6,"Delete key")
    ed.preview()
    check(c.attack_requested,"Preview triggers actual body")
    for i in range(16):c.advance(1.0/60,0,false)
    check(c.attack.active and c.attack.valid_pose,"Preview active")
    lab._update_hud()
    lab.queue_redraw()
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    await capture(dir.path_join("hybrid-intent.png"))
    ed.queue_free()
    for i in range(60):c.advance(1.0/60,0,false)
    check(c.attack.hit_count==1 and lab.dummy.hp==80,"Actual edited attack hits")
    lab._update_hud()
    lab.queue_redraw()
    await capture(dir.path_join("evolution-lab.png"))
    print("Intent editor and live evolution GL failures: ",failures)
    quit(0 if failures==0 else 1)
