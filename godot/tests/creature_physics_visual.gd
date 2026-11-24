extends SceneTree
const SCENE=preload("res://lab/physics_lab.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    root.size=Vector2i(960,540)
    var lab=SCENE.instantiate()
    root.add_child(lab)
    await process_frame
    lab.set_physics_process(false)
    var c=lab.creature
    for i in range(120):
        c.advance(1.0/60,0,false,false)
    for i in range(36):
        c.advance(1.0/60,1,false,false)
    var y: float=c.body.point("front").y
    c.advance(1.0/60,1,true,false)
    for i in range(14):
        c.advance(1.0/60,1,false,false)
    if c.body.point("front").y>=y-5 or c.body.penetration()>.05:
        push_error("Physics lab jump failed")
        quit(1)
        return
    lab._update_hud()
    lab.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    if root.get_texture().get_image().save_png(dir.path_join("physics-lab.png"))!=OK:
        quit(1)
        return
    lab.course=1
    lab._set_course()
    lab._reset()
    lab.creature=preload("res://addons/creature/physical_creature.gd").new(Vector2(263,390),lab.boxes,5,1,true)
    for i in range(75):lab.creature.advance(1.0/60,0,false,false,-1)
    if not lab.creature.surface.active or lab.creature.body.point("front").y>=340:
        push_error("Physics lab wall ascent failed")
        quit(1)
        return
    lab._update_hud()
    lab.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(dir.path_join("physics-wall.png"))!=OK:
        quit(1)
        return
    print("Physics Lab GL jump and wall captures passed")
    quit(0)
