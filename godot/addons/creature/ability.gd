extends RefCounted
## A portable four-phase ability profile; gameplay and visual presets are data.
const C=preload("res://addons/creature/clips.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const RIG=preload("res://addons/creature/rig.gd")
const PATH="user://creature_ability.json"
const PHASES=["charge","dash","contact","recovery"]
static func defaults() -> Dictionary:
    var rest: Dictionary=C.defaults().idle.keys[0].pose
    var charge: Dictionary=C.pose({"chest":18,"hips":10,"shoulder_near":38,"elbow_near":-138,"shoulder_far":-46,"elbow_far":-82,"thigh_near":-30,"knee_near":58,"thigh_far":20,"knee_far":-28},-3,2)
    var rush: Dictionary=C.pose({"chest":-23,"hips":-12,"shoulder_near":38,"elbow_near":-40,"shoulder_far":-50,"elbow_far":-80,"thigh_near":-42,"knee_near":46,"thigh_far":40,"knee_far":-22},0,1)
    var contact: Dictionary=C.aimed_key(0,{"chest":-14,"hips":-8,"shoulder_far":32,"elbow_far":-80,"thigh_near":-32,"knee_near":40,"thigh_far":23},4,0,"hand_near",Vector2(24,-12)).pose
    var charge_fx: Dictionary=P.demo(10)
    for l in charge_fx.layers:
        l.anchor="hand"
        l.size=5.0
        l.end_size=9.0
        l.field.thickness=1.0
        l.duration=.32
    var dash_fx: Dictionary=P.trail_demo()
    for l in dash_fx.layers:
        l.duration=.32
        if l.type=="trail":l.trail.life=.28
    var impact: Dictionary=P.demo(7)
    for l in impact.layers:
        l.follow=false
        l.end_size=28.0
        l.duration=.3
    return {"schema":1,"name":"Импульсный рывок","anchor":"hand_near","damage":24,"reach":19.0,"dash_speed":180.0,"start_pose":rest.duplicate(true),"impact":impact,
        "phases":[{"id":"charge","duration":.32,"pose":charge,"effect":charge_fx},{"id":"dash","duration":.32,"pose":rush,"effect":dash_fx},{"id":"contact","duration":.1,"pose":contact},{"id":"recovery","duration":.28,"pose":rest.duplicate(true)}]}

# Original demonstration: separate hand/shoulder emitters, a world-space
# ribbon, and a contact-only burst. No external art or baked animation.
static func electric_demo() -> Dictionary:
    var a: Dictionary=defaults()
    a.name="Электрический прорыв"
    a.damage=30
    a.reach=22.0
    a.dash_speed=220.0
    a.dash_accel=1100.0
    a.phases[0].duration=.48
    a.phases[1].duration=.46
    a.phases[2].duration=.12
    a.phases[3].duration=.36
    var charge: Dictionary=P.layer("glow")
    charge.anchor="hand"
    charge.duration=.48
    charge.color="#71bcff"
    charge.size=3.0
    charge.end_size=11.0
    charge.curves={"size":[[0.0,3.0],[.65,8.0],[1.0,11.0]],"alpha":[[0.0,.15],[.35,.85],[1.0,1.0]]}
    var corona: Dictionary=P.layer("lightning")
    corona.anchor="hand"
    corona.duration=.48
    corona.size=5.0
    corona.end_size=13.0
    corona.count=3
    corona.spread=360.0
    corona.color="#a4e2ff"
    corona.glow=.6
    corona.curves={"alpha":[[0.0,.1],[.4,.8],[1.0,1.0]]}
    var motes: Dictionary=P.layer("sparks")
    motes.anchor="hand"
    motes.duration=.48
    motes.follow=false
    motes.size=1.5
    motes.end_size=.5
    motes.speed=22.0
    motes.end_speed=8.0
    motes.gravity=0.0
    motes.spread=360.0
    motes.color="#86d8ff"
    motes.emitter={"rate":34.0,"life":.16,"life_jitter":.25,"shape":"disc","radius":5.0}
    a.phases[0].effect={"schema":1,"name":"Заряд в ладони","seed":318,"layers":[charge,corona,motes]}
    a.phases[0].effect_ref=.48
    var rush: Dictionary=P.trail_demo()
    rush.name="Электрический шлейф"
    rush.seed=733
    for l in rush.layers:
        l.duration=.46
        if l.type=="trail":
            l.trail.life=.31
            l.trail.rate=60.0
            l.trail.break_distance=32.0
            l.glow=.55
        else:
            l.size=10.0
            l.end_size=8.0
    var hand_bolts: Dictionary=corona.duplicate(true)
    hand_bolts.duration=.46
    hand_bolts.size=16.0
    hand_bolts.end_size=14.0
    hand_bolts.angle=160.0
    hand_bolts.spread=180.0
    hand_bolts.curves={"alpha":[[0.0,1.0],[.9,.9],[1.0,.7]]}
    rush.layers.append(hand_bolts)
    a.phases[1].effect=rush
    a.phases[1].effect_ref=.46
    var shoulder: Dictionary=corona.duplicate(true)
    shoulder.duration=.46
    shoulder.size=10.0
    shoulder.end_size=12.0
    shoulder.angle=20.0
    shoulder.spread=220.0
    shoulder.count=2
    shoulder.curves={"alpha":[[0.0,.4],[.2,1.0],[.85,.85],[1.0,.3]]}
    var elbow: Dictionary=shoulder.duplicate(true)
    elbow.size=9.0
    elbow.end_size=7.0
    elbow.angle=-10.0
    a.phases[1].accents=[
        {"anchor":"shoulder_near","effect":{"schema":1,"name":"Дуга плеча","seed":811,"layers":[shoulder]}},
        {"anchor":"elbow_near","effect":{"schema":1,"name":"Дуга предплечья","seed":812,"layers":[elbow]}}
    ]
    # Alternate leg poses during the actual dash, not just a static lean.
    var stride_a: Dictionary=a.phases[1].pose.duplicate(true)
    var stride_b: Dictionary=stride_a.duplicate(true)
    stride_b.angles["thigh_near"]=32.0
    stride_b.angles["knee_near"]=-24.0
    stride_b.angles["thigh_far"]=-42.0
    stride_b.angles["knee_far"]=48.0
    a.phases[1].keys=[{"u":.18,"pose":stride_a},{"u":.48,"pose":stride_b},{"u":.76,"pose":stride_a.duplicate(true)}]
    var thrust: Dictionary=hand_bolts.duplicate(true)
    thrust.duration=.12
    thrust.size=14.0
    thrust.end_size=7.0
    thrust.angle=0.0
    thrust.spread=100.0
    thrust.curves={"alpha":[[0.0,1.0],[.95,.8],[1.0,0.0]]}
    a.phases[2].effect={"schema":1,"name":"Выпад","seed":734,"layers":[thrust]}
    a.phases[2].effect_ref=.12
    var burst: Dictionary=P.layer("glow")
    burst.duration=.18
    burst.size=22.0
    burst.end_size=6.0
    burst.follow=false
    burst.color="#c9efff"
    var shock: Dictionary=P.layer("shockwave")
    shock.follow=false
    shock.duration=.26
    shock.size=3.0
    shock.end_size=28.0
    shock.count=2
    shock.field.thickness=1.5
    shock.color="#73b9ff"
    var fragments: Dictionary=P.layer("sparks")
    fragments.duration=.34
    fragments.follow=false
    fragments.count=22
    fragments.spread=360.0
    fragments.speed=105.0
    fragments.end_speed=28.0
    fragments.size=2.0
    fragments.end_size=.5
    fragments.gravity=30.0
    fragments.color="#bce7ff"
    var arcs: Dictionary=corona.duplicate(true)
    arcs.anchor="origin"
    arcs.follow=false
    arcs.duration=.20
    arcs.size=25.0
    arcs.end_size=9.0
    arcs.count=4
    arcs.curves={"alpha":[[0.0,1.0],[.4,.9],[1.0,0.0]]}
    a.impact={"schema":1,"name":"Электрический контакт","seed":941,"layers":[burst,shock,fragments,arcs]}
    return a

# Retiming changes layer emission windows, leaving individual particle and
# trail lifetimes intact. The source profile is never changed by compilation.
static func fit_effect(preset: Dictionary,phase: Dictionary) -> Dictionary:
    var out: Dictionary=preset.duplicate(true)
    if not phase.has("effect_ref"):return out
    var factor: float=float(phase.duration)/float(phase.effect_ref)
    for l in out.layers:
        l.start=clampf(float(l.start)*factor,0,5)
        l.duration=clampf(float(l.duration)*factor,.05,5)
    return out

static func valid_pose(value: Variant) -> bool:
    if not value is Dictionary or not value.get("angles") is Dictionary or not value.get("root") is Array or value.root.size()!=2:return false
    for v in value.root+value.angles.values():
        if not P.num(v,-1000,1000):return false
    return true

static func valid(a: Variant) -> bool:
    if not a is Dictionary or a.get("schema")!=1 or not a.get("name") is String:return false
    if not a.get("anchor") is String or not RIG.humanoid().ids.has(a.anchor):return false
    if not P.num(a.get("damage"),1,60) or floorf(float(a.damage))!=float(a.damage):return false
    if not P.num(a.get("reach"),4,30) or not P.num(a.get("dash_speed"),20,260):return false
    if a.has("dash_accel") and not P.num(a.dash_accel,100,4000):return false
    if not valid_pose(a.get("start_pose")) or not a.get("phases") is Array or a.phases.size()!=4:return false
    if a.has("impact") and not P.valid(a.impact):return false
    for i in range(4):
        var phase: Variant=a.phases[i]
        if not phase is Dictionary or phase.get("id")!=PHASES[i] or not P.num(phase.get("duration"),.05,2.0) or not valid_pose(phase.get("pose")):return false
        if phase.has("effect") and not P.valid(phase.effect):return false
        if phase.has("effect_ref") and not P.num(phase.effect_ref,.05,2.0):return false
        var accents: Variant=phase.get("accents",[])
        if not accents is Array or accents.size()>3:return false
        for accent in accents:
            if not accent is Dictionary or not accent.get("anchor") is String or not RIG.humanoid().ids.has(accent.anchor) or not P.valid(accent.get("effect")):return false
        var keys: Variant=phase.get("keys",[])
        if not keys is Array or keys.size()>12:return false
        var prior: float=0
        for key in keys:
            if not key is Dictionary or not P.num(key.get("u"),.01,.99) or float(key.u)<=prior or not valid_pose(key.get("pose")):return false
            prior=float(key.u)
    return true

static func phase_start(a: Dictionary,index: int) -> float:
    var at: float=0
    for i in range(clampi(index,0,4)):at+=float(a.phases[i].duration)
    return at

static func phase_at(a: Dictionary,t: float) -> String:
    for i in range(4):
        if t<phase_start(a,i+1):return PHASES[i]
    return "done"

static func compile(a: Dictionary) -> Dictionary:
    if not valid(a):return {}
    var keys: Array=[{"t":0.0,"pose":a.start_pose.duplicate(true)}]
    var events: Array=[]
    for i in range(4):
        var phase: Dictionary=a.phases[i]
        var start: float=phase_start(a,i)
        var end: float=phase_start(a,i+1)
        if phase.has("effect"):
            events.append({"t":start,"kind":"vfx","anchor":a.anchor,"preset":fit_effect(phase.effect,phase)})
        for accent in phase.get("accents",[]):
            events.append({"t":start,"kind":"vfx","anchor":accent.anchor,"preset":fit_effect(accent.effect,phase)})
        for key in phase.get("keys",[]):
            keys.append({"t":lerpf(start,end,float(key.u)),"pose":key.pose.duplicate(true)})
        # Contact pose is reached at the exact strike marker.
        keys.append({"t":end,"pose":phase.pose.duplicate(true)})
        if i==2:events.append({"t":end,"kind":"strike","anchor":a.anchor})
    events.sort_custom(func(x,y):return float(x.t)<float(y.t))
    return {"duration":phase_start(a,4),"loop":false,"keys":keys,"events":events}

static func load_profile(path: String=PATH) -> Dictionary:
    if FileAccess.file_exists(path):
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if valid(data):return data
    return electric_demo()

static func save_profile(a: Dictionary,path: String=PATH) -> bool:
    if not valid(a):return false
    var f:=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return false
    f.store_string(JSON.stringify(a,"  "))
    return true
