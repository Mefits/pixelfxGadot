extends SceneTree
const S=preload("res://lab/vfx_workshop.tscn")
const P=preload("res://addons/pixelfx/composer/preset.gd")
var failures: int=0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _run() -> void:
    root.size=Vector2i(960,540)
    var scene=S.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    scene.advanced_mode=true
    scene._apply_mode()
    scene.playing=false
    scene.kind.select(P.TYPES.find("smoke"))
    scene._add_layer()
    check(scene.preset.layers.size()==5,"Add layer")
    scene.fields.start.value=.3
    scene.fields.color.color=Color("#daaa76")
    scene.fields.color.color_changed.emit(Color("#daaa76"))
    check(is_equal_approx(float(scene.preset.layers[4].start),.3) and scene.preset.layers[4].color=="#daaa76","Inspector changes")
    scene._toggle_emitter(true)
    scene.emitter_fields.rate.value=20
    scene.emitter_fields.shape.select(1)
    scene.emitter_fields.shape.item_selected.emit(1)
    check(P.is_stream(scene.preset.layers[4]) and scene.preset.layers[4].emitter.rate==20 and scene.preset.layers[4].emitter.shape=="disc","Stream inspector")
    scene._copy_layer()
    check(scene.preset.layers.size()==6,"Duplicate")
    scene._move_layer(-1)
    scene._delete_layer()
    check(scene.preset.layers.size()==5,"Reorder and delete")
    scene.name_edit.text="UI test preset"
    scene.preset.name="UI test preset"
    scene._save()
    check(FileAccess.file_exists(P.FOLDER.path_join("UI_test_preset.json")),"Workshop save")
    for i in range(scene.library.item_count):
        if scene.library.get_item_text(i)=="UI_test_preset.json":scene.library.select(i)
    scene._load()
    check(scene.preset.layers.size()==5,"Workshop reload")
    check(P.is_stream(scene.preset.layers[4]),"Stream settings persisted")
    scene.stage.moving=true
    scene._seek(.32)
    await process_frame
    await process_frame
    check(scene.renderer.active_layers>=2 and scene.renderer.batch.accelerated_calls>0,"Rendered edited effect")
    check(scene.timeline.get_global_rect().end.y<=540 and scene.list.get_global_rect().end.x<=194 and scene.perf.get_global_rect().end.x<=686,"Workshop fits screen")
    var dir: String=ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(dir)
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(dir.path_join("vfx-workshop.png"))==OK,"Capture VFX")
    scene._select_demo(5)
    scene._seek(.8)
    await process_frame
    await process_frame
    check(scene.renderer.trail_segments>0 and scene.stage.moving,"Trail demo visible")
    scene.trail_fields.life.value=.9
    check(is_equal_approx(float(scene.preset.layers[0].trail.life),.9),"Trail inspector")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(dir.path_join("vfx-trail.png"))==OK,"Capture trail")
    scene._select_demo(6)
    scene._seek(.8)
    await process_frame
    await process_frame
    check(scene.renderer.organic_segments>0,"Organic demo visible")
    scene.organic_fields.length.value=65
    check(is_equal_approx(float(scene.preset.layers[0].organic.length),65.0),"Organic inspector")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(dir.path_join("vfx-organic.png"))==OK,"Capture organic")
    for i in range(P.FIELD_TYPES.size()):
        scene._select_demo(i+7)
        scene._seek(float(scene.preset.layers[0].duration)*.4)
        await process_frame
        await process_frame
        check(scene.renderer.field_segments>0,"Field demo "+P.FIELD_TYPES[i])
        scene.field_parameters.thickness.value=4.0
        check(is_equal_approx(float(scene.preset.layers[0].field.thickness),4.0),"Field inspector")
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(dir.path_join("vfx-"+P.FIELD_TYPES[i]+".png"))==OK,"Capture field")
    scene._select_demo(0)
    scene._seek(.3)
    await process_frame
    await process_frame
    check(scene.inspector.get_tab_count()==4,"Inspector tabs")
    check(not scene.field_rows.speed.visible,"Hide irrelevant speed")
    scene._capture_reference()
    scene._toggle_compare()
    scene._change("size",35.0)
    check(float(scene.reference.layers[0].size)!=35.0,"Independent A snapshot")
    await process_frame
    await process_frame
    check(scene.compare_picture.visible and scene.compare_renderer.active_layers>0,"A/B rendered")
    check(scene.picture.size==Vector2(240,160) and scene.compare_picture.size==scene.picture.size,"Equal comparison scale")
    scene.timeline.zoom_at(2.0,220.0)
    check(scene.timeline.zoom>1 and scene.timeline.span()<scene.timeline.total(),"Timeline zoom")
    scene.timeline.reset_view()
    check(is_equal_approx(scene.timeline.time_at(scene.timeline.size.x-4),scene._effect_duration()),"Timeline full extent")
    scene._select_layer(2)
    check(scene.selected==2 and scene.list.is_selected(2),"Timeline layer selection")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(dir.path_join("vfx-compare.png"))==OK,"Capture comparison")
    scene._toggle_compare()
    check(scene.picture.size==Vector2(480,320) and not scene.compare_picture.visible,"Restore full preview")
    var before:Dictionary=scene.preset.duplicate(true)
    scene.advanced_mode=false
    scene._apply_mode()
    check(scene.inspector.is_tab_hidden(2) and scene.play_button.is_visible_in_tree(),"Simple VFX mode")
    scene.advanced_mode=true
    scene._apply_mode()
    check(not scene.inspector.is_tab_hidden(2) and scene.preset==before,"Mode does not mutate preset")
    var space:=InputEventKey.new()
    space.physical_keycode=KEY_SPACE
    space.pressed=true
    scene.playing=false
    scene._input(space)
    check(scene.playing,"Space plays VFX")
    scene._input(space)
    check(not scene.playing,"Space pauses VFX")
    var del:=InputEventKey.new()
    del.physical_keycode=KEY_DELETE
    del.pressed=true
    scene.list.grab_focus()
    scene._input(del)
    check(scene.preset.layers.size()==before.layers.size()-1,"Delete layer")
    scene._undo()
    check(scene.preset==before,"Undo layer delete")
    scene.name_edit.grab_focus()
    scene._input(del)
    check(scene.preset==before,"Delete in text input does not remove layer")
    scene.name_edit.release_focus()
    scene.inspector.current_tab=2
    scene._select_layer(0)
    if not P.has_curve(scene.preset.layers[0],"size"):
        scene.curve_channel=0
        scene._toggle_curve()
    scene.curve_channel=0
    scene._sync_curve()
    scene.graph.points=[[0,4],[.5,6],[1,8]]
    scene._curve_changed(scene.graph.points)
    scene.graph.chosen=1
    scene.graph.grab_focus()
    var count:int=scene.preset.layers.size()
    scene._input(del)
    check(scene.preset.layers.size()==count and scene.preset.layers[0].curves["size"].size()==2,"Delete curve point without deleting layer")
    scene._mark_clean()
    check(not scene._has_changes(),"Clean baseline")
    scene._change("glow",.37)
    check(scene._has_changes(),"Unsaved edit tracked")
    var proceeded:Array=[false]
    scene._guard_change(func():proceeded[0]=true)
    check(scene.leave_dialog.visible and not proceeded[0],"Unsaved guard blocks navigation")
    scene.leave_dialog.hide()
    scene.pending_action=Callable()
    scene._undo()
    check(not scene._has_changes(),"Undo to saved state is clean")
    scene.catalog_entry={"source":"library","id":"copy_test"}
    scene._select_demo(0)
    check(scene.catalog_entry.is_empty() and not scene._has_changes(),"New demo detached from old copy")
    print("VFX workshop GL failures: ",failures)
    quit(0 if failures==0 else 1)
