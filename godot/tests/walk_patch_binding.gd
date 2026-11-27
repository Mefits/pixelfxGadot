extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
func _initialize():call_deferred("run")
func run():
    var editor=load("res://lab/authoring/editor.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    var ok:bool=editor.document.id=="walk_idle" and editor.document.keys.size()==1 and editor.last_image!=null
    editor.open_motion("walk_forward")
    ok=ok and editor.editable_bone("thigh_near") and editor.pose_tool.selected==1 and editor.document.keys.size()==9
    editor.seek(editor.START+8)
    for i in editor.key_channels.item_count:
        if editor.key_channels.get_item_metadata(i)=="shoulder_near":editor.key_channels.select(i)
    editor.sync_key()
    var old:float=editor.document.keys[1].angles.shoulder_near
    editor.key_angle.value=old+15.
    editor.apply_key_angle()
    var value:float=editor.document.keys[1].angles.shoulder_near
    ok=ok and absf(value-old)>10.
    editor.save_file()
    var stand=load("res://lab/walk_studio.tscn").instantiate()
    stand.manual=true
    root.add_child(stand)
    ok=ok and stand.last_ok and is_equal_approx(float(stand.walker.programs.walk_forward.doc.keys[1].angles.shoulder_near),value)
    stand.held[KEY_D]=true
    for t in 25:stand.advance()
    ok=ok and stand.walker.x>0.
    stand.held.clear()
    for t in 17:stand.advance()
    ok=ok and stand.walker.activity==0.
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Asset.FOLDER+"walk_forward.json"))
    if ok:print("WALK_PATCH_BINDING_OK")
    else:push_error("walk patch binding failed")
    quit(0 if ok else 1)
