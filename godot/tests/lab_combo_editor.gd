extends SceneTree
const CAT=preload("res://addons/creature/catalog.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=2:quit(2);return
    var entry:=CAT.import_file(args[0])
    if entry.is_empty():push_error("Import failed");quit(1);return
    set_meta(CAT.HANDOFF,entry)
    root.size=Vector2i(960,540)
    var scene=load("res://lab/pose_workshop.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    if not scene.preview.bag_visible or scene.bank.strike.keys.size()!=16 or scene.bank.strike.events.size()!=3:
        push_error("Imported editor state invalid");quit(1);return
    scene._seek(38.0/60.0)
    if not scene.pose.angles.has("shoulder_turn"):push_error("Shoulder channel missing");quit(1);return
    if not scene.pose.angles.has("pelvis_turn"):push_error("Pelvis channel missing");quit(1);return
    scene.pose.angles["pelvis_turn"]=70.0
    scene.pose.angles["shoulder_turn"]=25.0
    scene.pose.angles["elbow_far"]+=5.0
    scene._key()
    if not scene._export_json(args[1]):push_error("Export failed");quit(1);return
    var edited:=CAT.read_entry(args[1])
    if edited.is_empty() or not VALID.new().validate(edited).ok or edited.payload.clip==entry.payload.clip:
        push_error("Invalid edit roundtrip");quit(1);return
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(args[1].get_base_dir().path_join("editor-review.png"))
    DirAccess.remove_absolute(CAT.FOLDER.path_join(entry.id+".json"))
    print("LAB_EDITOR_ROUNDTRIP_OK")
    quit()
