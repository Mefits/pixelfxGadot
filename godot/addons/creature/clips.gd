extends RefCounted
## JSON-safe keyed poses and event markers. No dependency on humanoid joint names in sampling.
const SAVE_PATH="user://creature_clips.json"
const SECOND_PATH="user://creature_clips_fighter2.json"
const REQUIRED=["idle","walk","jump","strike","cast","guard","hurt"]
const NAMES=["idle","walk","jump","strike","cross","heavy","kick","air_strike","cast","guard","hurt","hurt_heavy"]

static func pose(a: Dictionary={},x: float=0,y: float=0) -> Dictionary:
    return {"angles":a,"root":[x,y]}

static func key(t: float,a: Dictionary={},x: float=0,y: float=0) -> Dictionary:
    return {"t":t,"pose":pose(a,x,y)}

static func defaults() -> Dictionary:
    var idle={"shoulder_near":-32,"elbow_near":-72,"shoulder_far":30,"elbow_far":-75,"thigh_near":-13,"knee_near":25,"thigh_far":13,"knee_far":-25}
    var bank: Dictionary={
        "idle":{"duration":1.2,"loop":true,"keys":[key(0,idle),key(.6,idle,0,-.8),key(1.2,idle)],"events":[]},
        "walk":{"duration":.6,"loop":true,"keys":[key(0,{"thigh_near":-32,"thigh_far":32,"knee_near":12,"knee_far":-20,"shoulder_near":25,"shoulder_far":-25}),key(.15,{"knee_near":-40,"knee_far":25},0,-2),key(.3,{"thigh_near":32,"thigh_far":-32,"knee_near":-20,"knee_far":12,"shoulder_near":-25,"shoulder_far":25}),key(.45,{"knee_far":-40,"knee_near":25},0,-2),key(.6,{"thigh_near":-32,"thigh_far":32,"knee_near":12,"knee_far":-20,"shoulder_near":25,"shoulder_far":-25})],"events":[]},
        "jump":{"duration":.5,"loop":false,"keys":[key(0,{"thigh_near":-45,"knee_near":72,"thigh_far":25,"knee_far":-50,"shoulder_near":-60,"elbow_near":-30}),key(.5,{"thigh_near":-15,"knee_near":30,"thigh_far":20,"knee_far":-30})],"events":[]},
        "strike":{"duration":.46,"loop":false,"keys":[key(0,idle),key(.12,{"hips":8,"chest":18,"shoulder_near":65,"elbow_near":-110,"shoulder_far":-25,"thigh_near":-25,"knee_near":45},-3,1),key(.20,{"hips":-8,"chest":-10,"shoulder_near":-78,"elbow_near":-12,"shoulder_far":38,"thigh_near":-25,"knee_near":35},5,0),key(.46,idle)],"events":[{"t":.20,"kind":"strike","anchor":"hand_near"}]},
        "cast":{"duration":.85,"loop":false,"keys":[key(0,idle),key(.28,{"shoulder_near":25,"elbow_near":-145,"shoulder_far":-48,"elbow_far":-75,"chest":12},-2,2),key(.45,{"shoulder_near":-83,"elbow_near":-8,"chest":-8,"shoulder_far":-24,"elbow_far":-85},2,0),key(.62,{"shoulder_near":-75,"elbow_near":-10}),key(.85,idle)],"events":[{"t":.12,"kind":"charge","anchor":"hand_near"},{"t":.45,"kind":"cast","anchor":"hand_near"}]},
        "guard":{"duration":.5,"loop":true,"keys":[key(0,{"shoulder_near":-72,"elbow_near":-105,"shoulder_far":-55,"elbow_far":-105,"thigh_near":-25,"knee_near":45},-1,3),key(.5,{"shoulder_near":-72,"elbow_near":-105,"shoulder_far":-55,"elbow_far":-105,"thigh_near":-25,"knee_near":45},-1,3)],"events":[]},
        "hurt":{"duration":.26,"loop":false,"keys":[key(0,{"chest":30,"shoulder_near":25,"shoulder_far":50},-3,0),key(.26,idle)],"events":[]}
    }
    bank.merge(extra_clips(bank))
    return bank

static func sample(clip: Dictionary,time: float,wrap_loop: bool=true) -> Dictionary:
    var duration: float=float(clip.duration)
    var t: float=fposmod(time,duration) if clip.loop and wrap_loop else clampf(time,0,duration)
    var keys: Array=clip.keys
    if keys.size()==1 or t<=float(keys[0].t):
        return keys[0].pose.duplicate(true)
    if t>=float(keys[-1].t):
        return keys[-1].pose.duplicate(true)
    for i in range(1,keys.size()):
        if is_equal_approx(t,float(keys[i].t)):
            return keys[i].pose.duplicate(true)
        if t<float(keys[i].t):
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
        if not bank.has(name):
            if name in REQUIRED:return false
            continue
        if not bank[name] is Dictionary:return false
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
        if valid(data): return complete(data)
    return defaults()

static func fighter_bank(index: int) -> Dictionary:
    if index==0:
        return load_bank()
    if FileAccess.file_exists(SECOND_PATH):
        return load_bank(SECOND_PATH)
    # Distinct heavy fighter timing; same editable joint graph.
    var bank: Dictionary=defaults()
    for name in ["strike","cross","heavy","kick","air_strike","cast"]:
        var factor: float=1.15 if name=="cast" else 1.3
        bank[name].duration*=factor
        for k in bank[name].keys:k.t*=factor
        for e in bank[name].events:e.t*=factor
    for k in bank.idle.keys:
        k.pose.angles["chest"]=-8
        k.pose.angles["shoulder_far"]=20
        k.pose.angles["elbow_far"]=-95
    return bank

static func blend_pose(a: Dictionary,b: Dictionary,u: float) -> Dictionary:
    if a.is_empty():return b.duplicate(true)
    u=clampf(u,0,1)
    var ids: Array=a.angles.keys()
    for id in b.angles:
        if not ids.has(id):ids.append(id)
    var out: Dictionary={}
    for id in ids:
        out[id]=rad_to_deg(lerp_angle(deg_to_rad(float(a.angles.get(id,0))),deg_to_rad(float(b.angles.get(id,0))),u))
    return pose(out,lerpf(a.root[0],b.root[0],u),lerpf(a.root[1],b.root[1],u))

static func followup(original: Dictionary) -> Dictionary:
    # Derive a faster cross from the user's existing strike, not a new save slot.
    var c: Dictionary=original.duplicate(true)
    var r=preload("res://addons/creature/rig.gd").humanoid()
    c.duration*=.82
    for k in c.keys:
        k.t*=.82
        r.evaluate(k.pose)
        var aim: Vector2=r.point("hand_near")
        k.pose.angles["shoulder_near"]=-32
        k.pose.angles["elbow_near"]=-72
        k.pose=r.solve_ik(k.pose,"hand_far",aim,24)
    for e in c.events:
        e.t*=.82
        if e.anchor=="hand_near" and e.kind=="strike":e.anchor="hand_far"
    return c

static func complete(bank: Dictionary) -> Dictionary:
    var result: Dictionary=bank.duplicate(true)
    var extra: Dictionary=extra_clips(result)
    for name in extra:
        if not result.has(name):result[name]=extra[name]
    return result

static func aimed_key(t: float,a: Dictionary,x: float,y: float,joint: String,goal: Vector2) -> Dictionary:
    var r=preload("res://addons/creature/rig.gd").humanoid()
    var p: Dictionary=pose(a,x,y)
    r.evaluate(p)
    p=r.solve_ik(p,joint,r.point("hips")+goal,32)
    return {"t":t,"pose":p}

static func extra_clips(bank: Dictionary) -> Dictionary:
    var idle: Dictionary=bank.idle.keys[0].pose
    var end: Dictionary=idle.duplicate(true)
    return {
        "cross":followup(bank.strike),
        "heavy":{"duration":.76,"loop":false,"keys":[{"t":0.0,"pose":idle.duplicate(true)},key(.23,{"hips":16,"chest":23,"shoulder_near":88,"elbow_near":-125,"shoulder_far":-50,"elbow_far":-65,"thigh_near":-25,"knee_near":55,"thigh_far":25,"knee_far":-30},-5,3),aimed_key(.34,{"hips":-15,"chest":-12,"shoulder_far":35,"elbow_far":-85,"thigh_near":-30,"knee_near":40,"thigh_far":25},7,1,"hand_near",Vector2(25,-13)),key(.45,{"hips":-12,"chest":-8,"shoulder_near":-72,"elbow_near":-25,"thigh_near":-25,"knee_near":35},5,2),{"t":.76,"pose":end.duplicate(true)}],"events":[{"t":.34,"kind":"strike","anchor":"hand_near"}]},
        "kick":{"duration":.61,"loop":false,"keys":[{"t":0.0,"pose":idle.duplicate(true)},key(.16,{"hips":12,"chest":10,"thigh_near":-105,"knee_near":95,"thigh_far":-10,"knee_far":20,"shoulder_near":-55,"elbow_near":-70},-2,-1),aimed_key(.26,{"hips":12,"chest":10,"thigh_far":-10,"knee_far":20,"shoulder_near":-45,"elbow_near":-95,"shoulder_far":35,"elbow_far":-60},3,-1,"foot_near",Vector2(22,-8)),key(.36,{"thigh_near":-100,"knee_near":95,"shoulder_near":-50,"elbow_near":-80},1,0),{"t":.61,"pose":end.duplicate(true)}],"events":[{"t":.26,"kind":"strike","anchor":"foot_near"}]},
        "air_strike":{"duration":.43,"loop":false,"keys":[key(0,{"thigh_near":-40,"knee_near":65,"thigh_far":20,"knee_far":-45,"shoulder_near":25,"elbow_near":-125}),aimed_key(.16,{"hips":-15,"chest":-15,"thigh_near":-35,"knee_near":55,"thigh_far":25,"knee_far":-45,"shoulder_far":40,"elbow_far":-65},3,0,"hand_near",Vector2(24,1)),key(.28,{"hips":-5,"thigh_near":-50,"knee_near":70,"shoulder_near":-55,"elbow_near":-50}),{"t":.43,"pose":end.duplicate(true)}],"events":[{"t":.16,"kind":"strike","anchor":"hand_near"}]},
        "hurt_heavy":{"duration":.46,"loop":false,"keys":[key(0,{"hips":20,"chest":35,"head":15,"shoulder_near":65,"shoulder_far":70,"thigh_near":25,"knee_near":-30,"thigh_far":-25,"knee_far":45},-6,-2),key(.14,{"hips":12,"chest":28,"thigh_near":-20,"knee_near":45,"thigh_far":20,"knee_far":-25},-4,3),{"t":.46,"pose":end.duplicate(true)}],"events":[]}
    }
