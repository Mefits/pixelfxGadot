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
    var before_move: Dictionary=ed.bank.strike.duplicate(true)
    ed._move_marker(0,2,.18)
    check(is_equal_approx(ed.time,.18) and ed.bank.strike.keys.size()==n+1,"Move pose marker")
    ed._move_marker(0,2,.2)
    check(is_equal_approx(float(ed.bank.strike.keys[2].t),.18),"Reject key collision")
    ed._undo()
    check(ed.bank.strike==before_move,"Undo marker move")
    ed._move_marker(1,0,.16)
    check(is_equal_approx(float(ed.bank.strike.events[0].t),.16),"Move event marker")
    ed._undo()
    ed._seek(.2)
    var original: Dictionary=ed.pose.duplicate(true)
    ed._mirror_pose()
    check(is_equal_approx(float(ed.pose.root[0]),-float(original.root[0])),"Mirror root")
    check(is_equal_approx(float(ed.pose.angles.get("shoulder_far",0)),-float(original.angles.get("shoulder_near",0))),"Mirror arms")
    ed._mirror_pose()
    check(ed.pose==original,"Mirror twice")
    ed._undo()
    ed._undo()
    var saved: Dictionary=ed.bank.strike.duplicate(true)
    ed._blank_clip()
    check(ed.bank.strike.keys.size()==2 and ed.bank.strike.events.is_empty(),"Blank clip")
    ed._undo()
    check(ed.bank.strike==saved,"Blank clip reversible")
    ed._seek(.2)
    # Exercise input handlers, not only the editing commands.
    var marker_press:=InputEventMouseButton.new()
    marker_press.button_index=MOUSE_BUTTON_LEFT
    marker_press.pressed=true
    marker_press.position=Vector2(ed.timeline.at(.2),20)
    ed.timeline._gui_input(marker_press)
    var motion:=InputEventMouseMotion.new()
    motion.position=Vector2(ed.timeline.at(.24),20)
    motion.button_mask=MOUSE_BUTTON_MASK_LEFT
    ed.timeline._gui_input(motion)
    var marker_release:=InputEventMouseButton.new()
    marker_release.button_index=MOUSE_BUTTON_LEFT
    marker_release.position=motion.position
    ed.timeline._gui_input(marker_release)
    check(is_equal_approx(ed.time,.24),"Timeline drag input")
    ed._undo()
    ed._seek(.2)
    ed.selected="chest"
    ed._sync()
    var pivot: Vector2=(ed.rig.point("chest")+ed.preview.origin)*4
    var old_angle: float=ed.pose.angles.get("chest",0)
    var rot_press:=InputEventMouseButton.new()
    rot_press.button_index=MOUSE_BUTTON_RIGHT
    rot_press.pressed=true
    rot_press.position=pivot+Vector2(40,0)
    ed._drag(rot_press)
    var rot_motion:=InputEventMouseMotion.new()
    rot_motion.position=pivot+Vector2(0,40)
    rot_motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
    ed._drag(rot_motion)
    var rot_release:=InputEventMouseButton.new()
    rot_release.button_index=MOUSE_BUTTON_RIGHT
    rot_release.position=rot_motion.position
    ed._drag(rot_release)
    check(is_equal_approx(float(ed.pose.angles.chest),wrapf(old_angle+90,-180,180)),"Mouse joint rotation")
    ed._undo()
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
    arena.training=true
    arena._reset()
    var sent_cast: bool=false
    for i in range(100):
        var cast_now: bool=arena.world.best_combo==2 and not sent_cast
        if cast_now:sent_cast=true
        arena.world.step(1.0/60,{"strike":i==0 or i==15,"cast":cast_now},{})
    arena.canvas.queue_redraw()
    arena._vfx()
    arena._update_hud()
    check(arena.world.best_combo>=2 and arena.detail.text.contains("тренировка"),"Training arena combo and HUD")
    check(arena.detail.get_global_rect().end.x<=960,"Combat detail fits viewport")
    await capture(dir.path_join("combat-combo.png"))
    arena.effects_on=false
    arena._vfx()
    check(arena.surface.painter.color.count(0)==arena.surface.painter.color.size(),"Disable effect layer")
    check(arena.world.best_combo>=2,"VFX toggle does not change simulation")
    print("Workshop interaction and actual GL preview failures: ",failures)
    quit(0 if failures==0 else 1)
