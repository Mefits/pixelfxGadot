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
    editor.apply_key_angle()
    if not is_equal_approx(float(editor.document.keys[key].angles[channel]),old+1.):
        push_error("key angle edit")
        quit(1)
        return
    editor.undo()
    if not is_equal_approx(float(editor.document.keys[key].angles[channel]),old):
        push_error("key undo")
        quit(1)
        return
    editor.seek_accent()
    editor.inspector.current_tab=2
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join("workshop-action.png"))!=OK:
        quit(1)
        return
    print("MOTION_WORKSPACE_UI_OK")
    quit()
