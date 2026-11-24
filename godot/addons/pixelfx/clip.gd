extends RefCounted
## Immutable preloaded clip. Schema 2 supports multiple atlas pages.
var id: String = ""
var fps: float = 30.0
var duration: float = 0.0
var loops: bool = false
var pivot := Vector2.ZERO
var frames: Array[Rect2] = []
var page_indices: Array[int] = []
var colors: Array[Texture2D] = []
var lights: Array[Texture2D] = []

static func read_clip(path: String) -> RefCounted:
    if not FileAccess.file_exists(path):
        return null
    var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not d is Dictionary or int(d.get("schema", 0)) != 2:
        push_error("Invalid PixelFX clip: " + path)
        return null
    var result = load("res://addons/pixelfx/clip.gd").new()
    result.id = str(d.get("id", ""))
    result.fps = float(d.get("fps", 0))
    result.duration = float(d.get("duration", 0))
    result.loops = bool(d.get("loop", false))
    var p: Array = d.get("pivot", [])
    if p.size() != 2 or result.fps <= 0.0 or result.duration <= 0.0:
        return null
    result.pivot = Vector2(float(p[0]), float(p[1]))
    for page in d.get("pages", []):
        var c: Texture2D = load(path.get_base_dir().path_join(str(page["color"]))) as Texture2D
        var l: Texture2D = load(path.get_base_dir().path_join(str(page["light"]))) as Texture2D
        if c == null or l == null or c.get_size() != l.get_size():
            return null
        result.colors.append(c)
        result.lights.append(l)
    for f in d.get("frames", []):
        var i: int = int(f["page"])
        var a: Array = f["rect"]
        if i < 0 or i >= result.colors.size() or a.size() != 4:
            return null
        var r := Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
        if r.size.x <= 0.0 or r.size.y <= 0.0 or not Rect2(Vector2.ZERO,result.colors[i].get_size()).encloses(r):
            return null
        result.frames.append(r)
        result.page_indices.append(i)
    if result.frames.is_empty():
        return null
    return result
