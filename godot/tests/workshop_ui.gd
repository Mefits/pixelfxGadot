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
    var error:=root.get_texture().get_image().save_png(out.path_join("workshop.png"))
    quit(0 if error==OK else 1)
