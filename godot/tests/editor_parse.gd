extends SceneTree
const PATHS=[
    "res://lab/authoring/asset.gd",
    "res://lab/authoring/goals.gd",
    "res://lab/authoring/dopesheet.gd",
    "res://lab/hybrid091/motion.gd",
    "res://lab/hybrid091/kernel.gd",
    "res://addons/creature/vfx_preview.gd",
    "res://addons/pixelfx/native/surface.gd",
    "res://lab/vfx_quick_dialog.gd",
    "res://lab/authoring/editor.gd"
]
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var failed:bool=false
    for path in PATHS:
        var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
        print("EDITOR_RESOURCE_PARSE ",path," ",resource!=null)
        if resource==null:failed=true
    quit(1 if failed else 0)
