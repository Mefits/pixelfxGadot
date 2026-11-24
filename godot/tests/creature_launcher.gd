extends SceneTree
const MAIN=preload("res://lab/main.tscn")
var failures: int=0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _run() -> void:
    root.size=Vector2i(960,540)
    var menu=MAIN.instantiate()
    root.add_child(menu)
    await process_frame
    await process_frame
    check(menu.routes.size()==7 and menu.buttons.size()==7,"All workspaces available")
    for key in ["H","E","O","K"]:check(not menu.routes.has(key),"Removed obsolete route "+key)
    for route in menu.routes.values():check(ResourceLoader.exists(route),"Scene exists "+route)
    for button in menu.buttons:check(button.get_global_rect().end.x<=960 and button.get_global_rect().end.y<=485,"Menu button fits")
    check(menu.get_child_count()==1,"No simulation or pool at startup")
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(dir.path_join("launcher.png"))==OK,"Launcher capture")
    root.remove_child(menu)
    menu.queue_free()
    change_scene_to_file("res://lab/main.tscn")
    await process_frame
    await process_frame
    var russian_key:=InputEventKey.new()
    russian_key.keycode=0x43D
    russian_key.physical_keycode=KEY_Y
    russian_key.pressed=true
    current_scene._unhandled_input(russian_key)
    await process_frame
    await process_frame
    check(current_scene.scene_file_path=="res://lab/vfx_workshop.tscn","Launch VFX using physical Y on Russian layout")
    change_scene_to_file("res://lab/main.tscn")
    await process_frame
    await process_frame
    check(current_scene.scene_file_path=="res://lab/main.tscn","Return to menu")
    print("Launcher graphical failures: ",failures)
    quit(0 if failures==0 else 1)
