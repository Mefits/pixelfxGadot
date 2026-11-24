extends RefCounted
## JSON-safe authored intent, independent of concrete limb lengths.
const PATH="user://creature_claw_track.json"
static func defaults() -> Dictionary:
    return {"duration":.56,"active_from":.19,"active_to":.32,"keys":[
        {"t":0.0,"x":.15,"y":.65,"tilt":-.12,"speed":0.0,"rear":0.0},
        {"t":.15,"x":-.65,"y":-.45,"tilt":.48,"speed":-20.0,"rear":3.0},
        {"t":.22,"x":.92,"y":-.30,"tilt":-.40,"speed":175.0,"rear":-2.0},
        {"t":.30,"x":.96,"y":.20,"tilt":-.25,"speed":155.0,"rear":-1.0},
        {"t":.42,"x":.30,"y":.65,"tilt":-.12,"speed":0.0,"rear":0.0},
        {"t":.56,"x":.15,"y":.65,"tilt":-.12,"speed":0.0,"rear":0.0}]}
static func number(v: Variant,lo: float,hi: float) -> bool:
    return (v is float or v is int) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi
static func valid(track: Variant) -> bool:
    if not track is Dictionary:return false
    if not number(track.get("duration"),.2,3) or not number(track.get("active_from"),0,float(track.duration)) or not number(track.get("active_to"),float(track.active_from)+.01,float(track.duration)):return false
    if not track.get("keys") is Array or track.keys.size()<2 or track.keys.size()>64:return false
    var last: float=-1
    for k in track.keys:
        if not k is Dictionary:return false
        if not number(k.get("t"),0,float(track.duration)) or float(k.t)<=last:return false
        for name in ["x","y","tilt"]:
            if not number(k.get(name),-1.5,1.5):return false
        if not number(k.get("speed"),-250,250) or not number(k.get("rear"),-8,8):return false
        last=k.t
    return is_zero_approx(float(track.keys[0].t)) and is_equal_approx(last,float(track.duration))
static func sample(track: Dictionary,t: float) -> Dictionary:
    t=clampf(t,0,float(track.duration))
    var k: Array=track.keys
    for i in range(1,k.size()):
        var a: Dictionary=k[i-1]
        var b: Dictionary=k[i]
        if t<=float(b.t):
            var u: float=(t-float(a.t))/(float(b.t)-float(a.t))
            u=u*u*(3-2*u)
            return {"claw":Vector2(lerpf(a.x,b.x,u),lerpf(a.y,b.y,u)),"tilt":lerpf(a.tilt,b.tilt,u),"speed":lerpf(a.speed,b.speed,u),"rear":lerpf(a.rear,b.rear,u)}
    var end: Dictionary=k[-1]
    return {"claw":Vector2(end.x,end.y),"tilt":end.tilt,"speed":end.speed,"rear":end.rear}
static func save_track(track: Dictionary,path: String=PATH) -> bool:
    if not valid(track):return false
    var f=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return false
    f.store_string(JSON.stringify(track,"  "))
    return true
static func load_track(path: String=PATH) -> Dictionary:
    if FileAccess.file_exists(path):
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if valid(data):return data
    return defaults()
