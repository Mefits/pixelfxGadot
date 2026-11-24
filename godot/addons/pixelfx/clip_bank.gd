extends RefCounted
## Prepare a set of clips in a loading scene; no loading in the attack path.
const CLIP=preload("res://addons/pixelfx/clip.gd")
var clips: Dictionary={}

func prepare(id: String,path: String) -> bool:
    if clips.has(id):
        return true
    var clip=CLIP.read_clip(path)
    if clip==null:
        return false
    clips[id]=clip
    return true

func prepare_many(manifests: Dictionary) -> bool:
    var success: bool=true
    for id in manifests:
        if not prepare(str(id),str(manifests[id])):
            success=false
    return success

func get_clip(id: String):
    return clips.get(id,null)

func release(id: String) -> void:
    clips.erase(id)
