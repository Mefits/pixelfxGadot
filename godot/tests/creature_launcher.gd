extends SceneTree
const CAT=preload("res://addons/creature/catalog.gd")
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
    check(menu.get_child_count()==1 and menu.preview==null,"No simulation or pool at startup")
    check(menu.entries.size()>=31,"Unified catalogue populated")
    for e in CAT.builtins():check(CAT.valid(e),"Builtin template valid: "+str(e.id))
    menu.category.select(1)
    menu.search.text="шлейф"
    menu._filter()
    check(menu.filtered.size()>=1,"Category and search")
    if not menu.filtered.is_empty():
        menu.catalog_list.select(0)
        menu._select_entry(0)
        check(is_instance_valid(menu.preview),"Lazy preview on selection")
    menu.search.text=""
    menu.category.select(0)
    menu._filter()
    check(menu.preview==null,"Preview released on filter")
    var builtin:Dictionary=CAT.builtins()[0]
    var copy:Dictionary=CAT.save_copy(builtin)
    check(not copy.is_empty() and copy.id!=builtin.id and copy.source=="library","Independent copy")
    if not copy.is_empty():
        var path:String=CAT.FOLDER.path_join(copy.id+".json")
        check(CAT.valid(CAT.read_entry(path)),"Copy roundtrip")
        var edited:Dictionary=copy.payload.duplicate(true)
        edited.name="Test edit"
        var saved:Dictionary=CAT.save_draft(copy,edited,edited.name)
        check(saved.id==copy.id and builtin.payload.name!=edited.name,"Only copy updated")
        DirAccess.remove_absolute(path)
    set_meta(CAT.HANDOFF,builtin)
    check(not CAT.consume(self,"vfx").is_empty() and not has_meta(CAT.HANDOFF),"One-shot handoff")
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
    for kind in CAT.KINDS:
        var entry:Dictionary={}
        for candidate in CAT.builtins():
            if candidate.kind==kind:entry=candidate;break
        set_meta(CAT.HANDOFF,entry)
        change_scene_to_file("res://lab/"+CAT.ROUTES[kind]+".tscn")
        await process_frame
        await process_frame
        check(not has_meta(CAT.HANDOFF) and current_scene.catalog_entry.id==entry.id,"Editor receives catalogue template: "+kind)
        if kind=="animation":check(current_scene.name_id==entry.payload.slot and current_scene.clip_select.disabled,"Isolated animation slot")
        if kind=="vfx":check(current_scene.preset.name==entry.payload.name,"Selected VFX opened")
        if kind=="ability":check(current_scene.ability_profile.name==entry.payload.name,"Selected ability opened")
        if kind=="creature":check(current_scene.creature.tail_count==entry.payload.tail,"Selected creature configuration opened")
        change_scene_to_file("res://lab/main.tscn")
        await process_frame
        await process_frame
    print("Launcher graphical failures: ",failures)
    quit(0 if failures==0 else 1)
