extends SceneTree
func _initialize():call_deferred("run")
func run():
    root.size=Vector2i(960,540)
    root.content_scale_size=root.size
    var editor=load("res://lab/authoring/editor.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    editor.seek_accent()
    var start:Vector2=editor.ORIGIN+editor.at_joint("hand_near")*editor.ZOOM
    var press:=InputEventMouseButton.new()
    press.position=start
    press.button_index=MOUSE_BUTTON_LEFT
    press.pressed=true
    root.push_input(press,true)
    var drag:=InputEventMouseMotion.new()
    drag.position=start+Vector2(-12,-36)
    drag.button_mask=MOUSE_BUTTON_MASK_LEFT
    root.push_input(drag,true)
    press.position=drag.position
    press.pressed=false
    root.push_input(press,true)
    if editor.document.goals.size()!=1 or not editor.raster:
        push_error("Viewport drag or native renderer missing")
        quit(1)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    var out:String=OS.get_cmdline_user_args()[0]
    if root.get_texture().get_image().save_png(out.path_join("workshop.png"))!=OK:
        quit(1)
        return
    editor.undo()
    if not editor.document.goals.is_empty():
        push_error("goal undo")
        quit(1)
        return
    editor.open_motion("jab")
    editor.seek_accent()
    var t:float=editor.document.keys[5].t
    var x:float=editor.timeline.at(editor.START+t*60.)
    var click:=InputEventMouseButton.new()
    click.button_index=MOUSE_BUTTON_LEFT
    click.position=editor.timeline.position+Vector2(x,37)
    click.pressed=true
    root.push_input(click,true)
    click.pressed=false
    root.push_input(click,true)
    if editor.inspector.current_tab!=2 or editor.key_at_frame()<0 or editor.key_apply.disabled:
        push_error("dopesheet key selection")
        quit(1)
        return
    var key:int=editor.key_at_frame()
    var channel:String=editor.key_channels.get_item_metadata(editor.key_channels.selected)
    var old:float=editor.document.keys[key].angles[channel]
    editor.key_angle.value=old+1.
    var requested:float=editor.key_angle.value
    editor.apply_key_angle()
    if absf(requested-old)<.5 or not is_equal_approx(float(editor.document.keys[key].angles[channel]),requested):
        push_error("key angle edit")
        quit(1)
        return
    editor.undo()
    if not is_equal_approx(float(editor.document.keys[key].angles[channel]),old):
        push_error("key undo")
        quit(1)
        return
    editor.redo()
    if not is_equal_approx(float(editor.document.keys[key].angles[channel]),requested):
        push_error("key redo")
        quit(1)
        return
    editor.undo()
    editor.seek_accent()
    editor.inspector.current_tab=2
    var snapshot:PackedByteArray=editor.player.save()
    editor.onion_enabled=true
    editor.update_ghosts()
    if editor.ghost_cache.size()!=2 or editor.player.save()!=snapshot:
        push_error("onion skin must not change current simulation")
        quit(1)
        return
    editor.curve_view.set_pressed_no_signal(true)
    editor.timeline.curve_mode=true
    editor.timeline.queue_redraw()
    if editor.timeline.curve_keys.size()!=editor.document.keys.size():
        push_error("curve data")
        quit(1)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join("workshop-action.png"))!=OK:
        quit(1)
        return
    editor.create_action("UI test action",.5)
    if editor.document.kind!="action" or editor.document.keys.size()!=2 or editor.document.name!="UI test action":
        push_error("new action")
        quit(1)
        return
    var id:String=editor.document.id
    editor.seek(editor.START+15)
    editor.key_pose()
    if editor.document.keys.size()!=3:
        push_error("new action pose insertion")
        quit(1)
        return
    editor.save_file()
    editor.open_motion(id)
    if editor.document.keys.size()!=3:
        push_error("new action persistence")
        quit(1)
        return
    DirAccess.remove_absolute(editor.Asset.FOLDER+id+".json")
    print("MOTION_WORKSPACE_UI_OK")
    quit()
