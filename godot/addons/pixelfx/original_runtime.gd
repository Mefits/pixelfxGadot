extends RefCounted
## Original JS runtime. Separate from the optimized native authored effects.
## One interpreter can host up to 128 effect/act instances. Main-thread only.
var backend: Object
var error: String=""
var entries: Array=[]

func open(path: String="res://generated/original_bundle.txt") -> bool:
    if not ClassDB.class_exists("PixelFXOriginal"):
        error="Original runtime extension unavailable"
        return false
    if not FileAccess.file_exists(path):
        error="Original runtime bundle not installed"
        return false
    backend=ClassDB.instantiate("PixelFXOriginal")
    if not backend.load_bundle(FileAccess.get_file_as_string(path)):
        error=backend.last_error()
        backend=null
        return false
    var d: Variant=JSON.parse_string(backend.catalog_json())
    if not d is Array:
        error="Catalog parse failed"
        backend=null
        return false
    entries=d
    return true

func create(id: String,options: Dictionary={},mode: String="fx") -> int:
    if backend==null:
        return 0
    var h: int=backend.create_effect(id,JSON.stringify(options),mode)
    if h==0:
        error=backend.last_error()
    return h

func destroy(h: int) -> void:
    if backend!=null:
        backend.destroy_effect(h)

func update(h: int,dt: float) -> bool:
    if backend==null:
        return false
    var ok: bool=backend.update_effect(h,dt)
    if not ok:
        error=backend.last_error()
    return ok

func stop(h: int) -> bool:
    return backend!=null and backend.stop_effect(h)

func state(h: int) -> Dictionary:
    if backend==null:
        return {}
    var d: Variant=JSON.parse_string(backend.state_json(h))
    return d if d is Dictionary else {}

func timing(id: String) -> Variant:
    return JSON.parse_string(backend.timing_json(id)) if backend!=null else null

func bounds(id: String) -> Dictionary:
    if backend==null:
        return {}
    var d: Variant=JSON.parse_string(backend.bounds_json(id))
    return d if d is Dictionary else {}

func pose(value: Dictionary) -> Dictionary:
    if backend==null:
        return {}
    var d: Variant=JSON.parse_string(backend.pose_json(JSON.stringify(value)))
    return d if d is Dictionary else {}

func placement(h: int,options: Dictionary) -> bool:
    return backend!=null and backend.placement(h,JSON.stringify(options))

func draw(h: int,p,layer: String="",body: bool=false,target: bool=true) -> bool:
    if backend==null:
        return false
    var out: Array=backend.render(h,p.width,p.height,p.ox,p.oy,layer,body,target,p.color,p.light)
    if out.size()!=2:
        error=backend.last_error()
        return false
    p.color=out[0]
    p.light=out[1]
    return true
