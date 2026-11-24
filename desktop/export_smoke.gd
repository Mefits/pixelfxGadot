extends Node
func _ready() -> void:
    var ok: bool=ClassDB.class_exists("PixelFXRaster") and ClassDB.class_exists("PixelFXOriginal")
    var runtime=preload("res://addons/pixelfx/original_runtime.gd").new()
    ok=runtime.open() and ok
    var clip=preload("res://addons/pixelfx/clip.gd").read_clip("res://generated/lightning_chain-lightning/clip.json")
    ok=clip!=null and ok
    var folder:=DirAccess.open("res://generated")
    ok=folder!=null and ok
    for name in ["main","pose_workshop","combat_lab","physics_lab","vfx_workshop","atlas_lab","original_catalog","live_lightning"]:
        ok=ResourceLoader.exists("res://lab/"+name+".tscn") and ok
    if not ok:
        push_error("EXPORTED_PACKAGE_SMOKE_FAILED: "+runtime.error)
        get_tree().quit(1)
        return
    print("EXPORTED_PACKAGE_SMOKE_OK")
    get_tree().quit(0)
