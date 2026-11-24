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
    scene.playing=false
    scene.kind.select(P.TYPES.find("smoke"))
    scene._add_layer()
    check(scene.preset.layers.size()==5,"Add layer")
    scene.fields.start.value=.3
    scene.fields.color.color=Color("#daaa76")
    scene.fields.color.color_changed.emit(Color("#daaa76"))
    check(is_equal_approx(float(scene.preset.layers[4].start),.3) and scene.preset.layers[4].color=="#daaa76","Inspector changes")
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
    print("VFX workshop GL failures: ",failures)
    quit(0 if failures==0 else 1)
