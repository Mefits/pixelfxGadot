extends RefCounted
## JSON-safe keyed poses and event markers. No dependency on humanoid joint names in sampling.
const SAVE_PATH="user://creature_clips.json"
const NAMES=["idle","walk","jump","strike","cast","guard","hurt"]

static func pose(a: Dictionary={},x: float=0,y: float=0) -> Dictionary:
    return {"angles":a,"root":[x,y]}

static func key(t: float,a: Dictionary={},x: float=0,y: float=0) -> Dictionary:
    return {"t":t,"pose":pose(a,x,y)}

static func defaults() -> Dictionary:
    var idle={"shoulder_near":-32,"elbow_near":-72,"shoulder_far":30,"elbow_far":-75,"thigh_near":-13,"knee_near":25,"thigh_far":13,"knee_far":-25}
    return {
        "idle":{"duration":1.2,"loop":true,"keys":[key(0,idle),key(.6,idle,0,-.8),key(1.2,idle)],"events":[]},
        "walk":{"duration":.6,"loop":true,"keys":[key(0,{"thigh_near":-32,"thigh_far":32,"knee_near":12,"knee_far":-20,"shoulder_near":25,"shoulder_far":-25}),key(.15,{"knee_near":-40,"knee_far":25},0,-2),key(.3,{"thigh_near":32,"thigh_far":-32,"knee_near":-20,"knee_far":12,"shoulder_near":-25,"shoulder_far":25}),key(.45,{"knee_far":-40,"knee_near":25},0,-2),key(.6,{"thigh_near":-32,"thigh_far":32,"knee_near":12,"knee_far":-20,"shoulder_near":25,"shoulder_far":-25})],"events":[]},
        "jump":{"duration":.5,"loop":false,"keys":[key(0,{"thigh_near":-45,"knee_near":72,"thigh_far":25,"knee_far":-50,"shoulder_near":-60,"elbow_near":-30}),key(.5,{"thigh_near":-15,"knee_near":30,"thigh_far":20,"knee_far":-30})],"events":[]},
        "strike":{"duration":.46,"loop":false,"keys":[key(0,idle),key(.12,{"hips":8,"chest":18,"shoulder_near":65,"elbow_near":-110,"shoulder_far":-25,"thigh_near":-25,"knee_near":45},-3,1),key(.20,{"hips":-8,"chest":-10,"shoulder_near":-78,"elbow_near":-12,"shoulder_far":38,"thigh_near":-25,"knee_near":35},5,0),key(.46,idle)],"events":[{"t":.20,"kind":"strike","anchor":"hand_near"}]},
        "cast":{"duration":.85,"loop":false,"keys":[key(0,idle),key(.28,{"shoulder_near":25,"elbow_near":-145,"shoulder_far":-48,"elbow_far":-75,"chest":12},-2,2),key(.45,{"shoulder_near":-83,"elbow_near":-8,"chest":-8,"shoulder_far":-24,"elbow_far":-85},2,0),key(.62,{"shoulder_near":-75,"elbow_near":-10}),key(.85,idle)],"events":[{"t":.12,"kind":"charge","anchor":"hand_near"},{"t":.45,"kind":"cast","anchor":"hand_near"}]},
        "guard":{"duration":.5,"loop":true,"keys":[key(0,{"shoulder_near":-72,"elbow_near":-105,"shoulder_far":-55,"elbow_far":-105,"thigh_near":-25,"knee_near":45},-1,3),key(.5,{"shoulder_near":-72,"elbow_near":-105,"shoulder_far":-55,"elbow_far":-105,"thigh_near":-25,"knee_near":45},-1,3)],"events":[]},
        "hurt":{"duration":.26,"loop":false,"keys":[key(0,{"chest":30,"shoulder_near":25,"shoulder_far":50},-3,0),key(.26,idle)],"events":[]}
    }

static func sample(clip: Dictionary,time: float) -> Dictionary:
    var duration: float=float(clip.duration)
    var t: float=fposmod(time,duration) if clip.loop else clampf(time,0,duration)
    var keys: Array=clip.keys
    if keys.size()==1 or t<=float(keys[0].t):
        return keys[0].pose.duplicate(true)
    for i in range(1,keys.size()):
        if t<=float(keys[i].t):
            var a: Dictionary=keys[i-1].pose
            var b: Dictionary=keys[i].pose
            var u: float=clampf((t-float(keys[i-1].t))/maxf(.000001,float(keys[i].t)-float(keys[i-1].t)),0,1)
            if clip.get("easing","smooth")=="smooth":
                u=u*u*(3-2*u)
            var angles: Dictionary={}
            var ids: Array=a.angles.keys()
            for id in b.angles:
                if not ids.has(id): ids.append(id)
            for id in ids:
                angles[id]=rad_to_deg(lerp_angle(deg_to_rad(float(a.angles.get(id,0))),deg_to_rad(float(b.angles.get(id,0))),u))
            return pose(angles,lerpf(float(a.root[0]),float(b.root[0]),u),lerpf(float(a.root[1]),float(b.root[1]),u))
    return keys[-1].pose.duplicate(true)

static func put_key(clip: Dictionary,t: float,value: Dictionary) -> void:
    t=clampf(t,0,float(clip.duration))
    for k in clip.keys:
        if absf(float(k.t)-t)<.0001:
            k.pose=value.duplicate(true)
            return
    clip.keys.append({"t":t,"pose":value.duplicate(true)})
    clip.keys.sort_custom(func(a,b): return float(a.t)<float(b.t))

static func events_between(clip: Dictionary,previous: float,current: float) -> Array:
    var out: Array=[]
    for e in clip.events:
        if float(e.t)>previous and float(e.t)<=current:
            out.append(e)
    return out

static func valid(bank: Variant) -> bool:
    if not bank is Dictionary:
        return false
    for name in NAMES:
        if not bank.has(name) or not bank[name] is Dictionary: return false
        var c: Dictionary=bank[name]
        if not (c.get("duration") is float or c.get("duration") is int) or float(c.duration)<=0 or float(c.duration)>10 or not c.get("loop") is bool or not c.get("keys") is Array or c.keys.is_empty() or c.keys.size()>600 or not c.get("events") is Array: return false
        var last: float=-1
        for k in c.keys:
            if not k is Dictionary or not (k.get("t") is float or k.get("t") is int) or float(k.t)<=last or float(k.t)>float(c.duration) or not k.get("pose") is Dictionary: return false
            last=float(k.t)
            var p: Dictionary=k.pose
            if not p.get("angles") is Dictionary or not p.get("root") is Array or p.root.size()!=2: return false
            for v in p.root+p.angles.values():
                if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v))>1000: return false
        for e in c.events:
            if not e is Dictionary or not (e.get("t") is float or e.get("t") is int) or float(e.t)<0 or float(e.t)>float(c.duration) or not e.get("kind") in ["strike","charge","cast"] or not e.get("anchor") is String: return false
    return true

static func save_bank(bank: Dictionary,path: String=SAVE_PATH) -> bool:
    if not valid(bank): return false
    var f=FileAccess.open(path,FileAccess.WRITE)
    if f==null: return false
    f.store_string(JSON.stringify(bank,"  "))
    return true

static func load_bank(path: String=SAVE_PATH) -> Dictionary:
    if FileAccess.file_exists(path):
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if valid(data): return data
    return defaults()
