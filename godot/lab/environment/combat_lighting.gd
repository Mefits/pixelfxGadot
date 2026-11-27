extends RefCounted
## Bridges actual native PixelFX Lights to masked, directional arena receivers.
## Native light lifetime and attenuation are preserved; reach is an explicit artistic scale.
const LIGHTS = preload("res://addons/pixelfx/native/lights.gd")
const PAL = preload("res://addons/pixelfx/native/palette.gd")
const RECEIVER = preload("res://lab/environment/combat_receiver.gdshader")
const MAX_LIGHTS: int = 8
var transient = LIGHTS.new()
var materials: Array[ShaderMaterial] = []
var effect_entries: Array[Dictionary] = []
var active_count: int = 0
var enabled: bool = true

func _init() -> void:
    transient.capacity = 32

func _rgb(packed: int) -> Color:
    return Color(float(packed&255)/255.0,float((packed>>8)&255)/255.0,float((packed>>16)&255)/255.0)

# The face colors in Cosmic Ruins are intentionally authored material IDs.
# Reuse their final Painter coverage as a mask and bake a separate approximate normal/response map.
# No inferred 3-D geometry or shadow casting is claimed.
func attach_receiver(sprite: Sprite2D, painter, is_floor: bool) -> void:
    var faces: Dictionary = {}
    for hex in ["102f52","12395e","15395e","123252","23567e","1c5078","1a4b76"]:
        faces[PAL.from_hex(hex)&0xffffff] = Vector3(-0.64,-0.16,0.75)
    for hex in ["0a1c33","0a213d","0b1729","0a2038","0a192e"]:
        faces[PAL.from_hex(hex)&0xffffff] = Vector3(0.65,-0.05,0.76)
    for hex in ["155488","103e69","206293","173e6c"]:
        faces[PAL.from_hex(hex)&0xffffff] = Vector3(0.0,-0.84,0.54)
    var pixels: PackedInt32Array = painter.color
    var data := PackedByteArray()
    data.resize(pixels.size()*4)
    for i in range(pixels.size()):
        var c: int = pixels[i]
        var idx: int = i*4
        if ((c>>24)&255)==0:
            continue
        var n: Vector3 = faces.get(c&0xffffff,Vector3(0,-0.12,0.99))
        var response: float = 0.65
        if is_floor:
            n = Vector3(0,-0.88,0.48)
            response = 0.48 if (c&0xffffff)==(PAL.from_hex("080e18")&0xffffff) else 0.78
        elif (c&0xffffff)==(PAL.from_hex("080e18")&0xffffff):
            response = 0.24
        data[idx] = int((n.x*0.5+0.5)*255)
        data[idx+1] = int((n.y*0.5+0.5)*255)
        data[idx+2] = int((n.z*0.5+0.5)*255)
        data[idx+3] = int(response*255)
    var normal_map := ImageTexture.create_from_image(Image.create_from_data(painter.width,painter.height,false,Image.FORMAT_RGBA8,data))
    var mat := ShaderMaterial.new()
    mat.shader = RECEIVER
    mat.set_shader_parameter("surface_map",normal_map)
    sprite.material = mat
    materials.append(mat)
    _apply()

func emit_light(at: Vector2, radius: float, tint: Color, energy: float, lifetime: float) -> bool:
    if not at.is_finite() or not is_finite(radius) or not is_finite(energy) or not is_finite(lifetime):
        return false
    if radius<=0 or energy<=0 or lifetime<=0:
        return false
    var c: int = PAL.rgb(clampf(tint.r,0,1)*255,clampf(tint.g,0,1)*255,clampf(tint.b,0,1)*255)
    var ok: bool = transient.add(at.x,at.y,clampf(radius,1,400),c,clampf(energy,0,3),lifetime)
    if ok:
        _apply()
    return ok

func tick(dt: float) -> void:
    if transient.list.is_empty():
        return
    transient.update(maxf(0,dt))
    _apply()

func _entry(at: Vector2, radius: float, tint: Color, energy: float) -> Dictionary:
    return {"position":at,"radius":clampf(radius,1,400),"color":tint,"energy":clampf(energy,0,3)}

func _read_lights(out: Array[Dictionary], source, origin: Vector2, scale: float, reach: float) -> void:
    for l in source.list:
        # Exact native Lights.draw envelope, with independent environmental reach.
        var k: float = clampf(float(l["life"])/maxf(0.00001,float(l["max"])),0,1)
        var pos := origin + Vector2(float(l["x"]),float(l["y"]))*scale
        var r: float = float(l["r"])*(0.55+0.45*k)*absf(scale)*reach
        var e: float = float(l["k"])*k*k
        if pos.is_finite() and r>0 and e>0.0001:
            out.append(_entry(pos,r,_rgb(int(l["color"])),e))

func publish(sources: Array, sustained: Array = []) -> void:
    effect_entries.clear()
    for source in sources:
        var emitter = source.get("lights")
        if emitter==null:
            continue
        _read_lights(effect_entries,emitter,source.get("origin",Vector2.ZERO),float(source.get("scale",1)),float(source.get("reach",1)))
    # Optional ongoing emissive cores, supplied from the real effect's own animation envelope.
    for e in sustained:
        var at: Vector2 = e.get("position",Vector2.ZERO)
        var r: float = e.get("radius",0.0)
        var power: float = e.get("energy",0.0)
        if at.is_finite() and r>0 and power>0.0001:
            effect_entries.append(_entry(at,r,e.get("color",Color.WHITE),power))
    _apply()

func clear() -> void:
    transient.list.clear()
    effect_entries.clear()
    _apply()

func set_enabled(value: bool) -> void:
    enabled = value
    _apply()

func _apply() -> void:
    var entries: Array[Dictionary] = effect_entries.duplicate()
    _read_lights(entries,transient,Vector2.ZERO,1.0,1.0)
    # Stable sort by energy times radius, preserving deterministic tie order.
    for i in range(1,entries.size()):
        var e: Dictionary = entries[i]
        var score: float = float(e["energy"])*float(e["radius"])
        var j: int = i-1
        while j>=0 and float(entries[j]["energy"])*float(entries[j]["radius"])<score:
            entries[j+1]=entries[j]
            j-=1
        entries[j+1]=e
    var geom := PackedVector4Array()
    var rgb := PackedVector4Array()
    geom.resize(MAX_LIGHTS)
    rgb.resize(MAX_LIGHTS)
    active_count = mini(entries.size(),MAX_LIGHTS) if enabled else 0
    for i in range(active_count):
        var e: Dictionary = entries[i]
        var p: Vector2 = e["position"]
        var c: Color = e["color"]
        geom[i]=Vector4(p.x,p.y,e["radius"],e["energy"])
        rgb[i]=Vector4(c.r,c.g,c.b,1)
    for mat in materials:
        mat.set_shader_parameter("light_count",active_count)
        mat.set_shader_parameter("light_geom",geom)
        mat.set_shader_parameter("light_rgb",rgb)
