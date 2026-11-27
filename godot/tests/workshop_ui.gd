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
    var graph_index:int=5
    var graph_old:float=editor.document.keys[graph_index].angles[channel]
    var graph_x:float=editor.timeline.at(editor.timeline.curve_keys[graph_index].x)
    click.position=editor.timeline.position+Vector2(graph_x,44)
    click.pressed=true
    root.push_input(click,true)
    drag.position=click.position+Vector2(0,-10)
    root.push_input(drag,true)
    click.position=drag.position
    click.pressed=false
    root.push_input(click,true)
    if absf(float(editor.document.keys[graph_index].angles[channel])-graph_old)<.5:
        push_error("curve drag did not edit key")
        quit(1)
        return
    editor.undo()
    editor.seek_accent()
    editor.channel_mode.select(1)
    editor.target_list.hide()
    editor.channel_tree.show()
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
    # Reference view is independent of document and current simulation.
    var ref_path:String="user://workspace_test_reference.png"
    editor.last_image.save_png(ref_path)
    var before:Dictionary=editor.document.duplicate(true)
    var state:PackedByteArray=editor.player.save()
    editor.load_reference(ref_path)
    editor.reference_scale.value=1.5
    editor.reference_x.value=35.
    if editor.reference_sprite.texture==null or not editor.reference_sprite.visible or editor.document!=before or editor.player.save()!=state:
        push_error("reference isolation")
        quit(1)
        return
    editor.inspector.current_tab=3
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join("workshop-reference.png"))!=OK:
        quit(1)
        return
    editor.clear_reference()
    DirAccess.remove_absolute(ref_path)
    editor.apply_release()
    if not editor.document.get("release",{}).has("near") or editor.Asset.problem(editor.document)!="":
        push_error("leg release")
        quit(1)
        return
    for k in editor.document.keys:
        for channel_id in ["thigh_near","knee_near","foot_pitch_near"]:
            if not k.angles.has(channel_id):
                push_error("leg channels")
                quit(1)
                return
    editor.seek(editor.START+15)
    if not editor.player.released.has("near"):
        push_error("authored leg not released in kernel")
        quit(1)
        return
    editor.undo()
    if editor.document!=before:
        push_error("leg undo")
        quit(1)
        return
    editor.redo()
    editor.remove_release()
    if editor.document.get("release",{}).has("near"):
        push_error("leg return")
        quit(1)
        return
    # FK editing is a transaction: live preview, one commit, no changes to IK goals.
    editor.seek(editor.START+11)
    editor.set_pose_tool(1)
    editor.onion_enabled=false
    for i in editor.key_channels.item_count:
        if editor.key_channels.get_item_metadata(i)=="shoulder_near":editor.key_channels.select(i)
    var source:Dictionary=editor.document.duplicate(true)
    var count:int=editor.history.size()
    var pts:Array=editor.bone_points("shoulder_near")
    var pivot:Vector2=pts[0]
    var handle:Vector2=pivot.lerp(pts[1],.7)
    press.position=handle
    press.pressed=true
    root.push_input(press,true)
    if not editor.rotate_active or editor.rotate_channel!="shoulder_near":
        push_error("FK bone selection "+editor.rotate_channel)
        quit(1)
        return
    drag.position=pivot+(handle-pivot).rotated(deg_to_rad(30.))
    root.push_input(drag,true)
    if editor.document!=source:
        push_error("FK preview mutated document")
        quit(1)
        return
    press.position=drag.position
    press.pressed=false
    root.push_input(press,true)
    var new_key:int=editor.key_at_frame()
    if new_key<0 or editor.document.keys.size()!=source.keys.size()+1 or editor.document.goals!=source.goals or editor.history.size()!=count+1:
        push_error("FK auto key transaction")
        quit(1)
        return
    var base_angle:float=editor.rotate_initial
    if absf(float(editor.document.keys[new_key].angles.shoulder_near)-base_angle-30.)>.2:
        push_error("FK angle")
        quit(1)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join("workshop-fk.png"))!=OK:
        quit(1)
        return
    editor.undo()
    if editor.document!=source:
        push_error("FK undo")
        quit(1)
        return
    editor.redo()
    # Root handle drag creates an authored XY key as a single undoable edit.
    editor.set_pose_tool(1)
    var root_before:int=editor.document.keys.size()
    var root_pos:Vector2=editor.root_handle_position()
    press.position=root_pos
    press.pressed=true
    root.push_input(press,true)
    if not editor.root_drag_active:
        push_error("root handle selection")
        quit(1)
        return
    drag.position=root_pos+Vector2(12,6)
    root.push_input(drag,true)
    press.position=drag.position
    press.pressed=false
    root.push_input(press,true)
    if editor.document.keys.size()!=root_before+1:
        push_error("root drag auto key")
        quit(1)
        return
    var root_key:int=editor.key_at_frame()
    if root_key<0 or absf(float(editor.document.keys[root_key].root[0]))<1.:
        push_error("root X authored")
        quit(1)
        return
    editor.undo()
    if editor.document.keys.size()!=root_before:
        push_error("root undo")
        quit(1)
        return
    editor.redo()
    if editor.document.keys.size()!=root_before+1:
        push_error("root redo")
        quit(1)
        return
    editor.set_pose_tool(2)
    if editor.edit_pose.size()!=0 or editor.last_image==null:
        push_error("resolved preview")
        quit(1)
        return
    # FPS/easing, event editing and legacy U bank import stay inside M.
    editor.set_fps(1)
    if editor.document.fps!=30 or not is_equal_approx(editor.timeline.step,2.):
        push_error("authoring fps grid")
        quit(1)
        return
    editor.set_easing(1)
    if editor.document.easing!="smooth":
        push_error("authoring easing")
        quit(1)
        return
    editor.event_kind.select(3)
    editor.event_anchor.select(editor.Asset.EVENT_ANCHORS.find("hand_near"))
    editor.vfx_select.select(0)
    editor.add_vfx_event()
    if editor.document.events.is_empty() or editor.document.events[-1].kind!="vfx" or not editor.fx_surface.visible:
        push_error("VFX event authoring and preview")
        quit(1)
        return
    editor.select_event(editor.document.events.size()-1)
    editor.open_quick_vfx()
    if not editor.quick_dialog.visible:
        push_error("quick VFX dialog")
        quit(1)
        return
    editor.quick_dialog.hide()
    var bank_path:String="user://workspace_legacy_bank.json"
    var bank_file:=FileAccess.open(bank_path,FileAccess.WRITE)
    bank_file.store_string(JSON.stringify(editor.Clips.defaults()))
    bank_file.close()
    editor.import_legacy_file(ProjectSettings.globalize_path(bank_path))
    if not editor.ids.has("u_strike") or not FileAccess.file_exists(editor.Asset.FOLDER+"u_strike.json"):
        push_error("legacy U bank import")
        quit(1)
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(bank_path))
    var exported_path:String="user://workspace_legacy_export.json"
    var exported_file:=FileAccess.open(exported_path,FileAccess.WRITE)
    exported_file.store_string(JSON.stringify({"name":"Exported Strike","payload":{"slot":"strike","clip":editor.Clips.defaults().strike}}))
    exported_file.close()
    editor.import_legacy_file(ProjectSettings.globalize_path(exported_path))
    if not FileAccess.file_exists(editor.Asset.FOLDER+"u_strike_1.json") and not FileAccess.file_exists(editor.Asset.FOLDER+"u_strike.json"):
        push_error("legacy catalog export import")
        quit(1)
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(exported_path))
    var imported_dir:=DirAccess.open(editor.Asset.FOLDER)
    if imported_dir:
        for file in imported_dir.get_files():
            if file.get_basename().begins_with("u_"):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(editor.Asset.FOLDER.path_join(file)))
    DirAccess.remove_absolute(editor.Asset.FOLDER+id+".json")
    print("MOTION_WORKSPACE_UI_OK")
    quit()
