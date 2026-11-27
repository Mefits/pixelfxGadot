extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
func _initialize():call_deferred("run")
func run():
    var editor=load("res://lab/authoring/editor.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    var ok:bool=editor.document.id=="walk_idle" and editor.document.keys.size()==1 and editor.last_image!=null
    for id in ["walk_idle","walk_breathe","walk_forward","walk_backward","jab","feint"]:
        editor.open_motion(id)
        ok=ok and editor.frame==editor.START and is_equal_approx(editor.timeline.at(editor.START),editor.timeline.LEFT)
        ok=ok and is_equal_approx(editor.timeline._time_at(editor.timeline.LEFT),float(editor.START))
        if editor.document.keys.size()>1:
            ok=ok and absf(editor.timeline.at(editor.START+editor.document.duration*60.)-(editor.timeline.size.x-10.))<1.
        editor.seek(0)
        ok=ok and editor.frame==editor.START
    editor.open_motion("walk_breathe")
    editor.seek(editor.START+roundi(float(editor.document.keys[1].t)*60.))
    for i in editor.key_channels.item_count:
        if editor.key_channels.get_item_metadata(i)=="shoulder_near":editor.key_channels.select(i)
    editor.sync_key()
    var old:float=editor.document.keys[1].angles.shoulder_near
    editor.key_angle.value=old+5.
    editor.apply_key_angle()
    var value:float=editor.document.keys[1].angles.shoulder_near
    ok=ok and absf(value-old)>4.
    editor.save_file()
    var stand=load("res://lab/walk_studio.tscn").instantiate()
    stand.manual=true
    root.add_child(stand)
    ok=ok and stand.last_ok and is_equal_approx(float(stand.walker.programs.walk_breathe.doc.keys[1].angles.shoulder_near),value)
    for t in 100:stand.advance()
    ok=ok and stand.walker.action_name()=="walk_breathe" and stand.walker.x==0.
    stand.held[KEY_D]=true
    for t in 25:stand.advance()
    ok=ok and stand.walker.x>0.
    stand.held.clear()
    for t in 17:stand.advance()
    ok=ok and stand.walker.activity==0.
    for t in 100:stand.advance()
    ok=ok and stand.walker.action_name()=="walk_breathe"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Asset.FOLDER+"walk_breathe.json"))
    if ok:print("IDLE_PATCH_BINDING_OK")
    else:push_error("idle patch binding or timeline failed")
    quit(0 if ok else 1)
