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
    if not valid_pose(a.get("start_pose")) or not a.get("phases") is Array or a.phases.size()!=4:return false
    if a.has("impact") and not P.valid(a.impact):return false
    for i in range(4):
        var phase: Variant=a.phases[i]
        if not phase is Dictionary or phase.get("id")!=PHASES[i] or not P.num(phase.get("duration"),.05,2.0) or not valid_pose(phase.get("pose")):return false
        if phase.has("effect") and not P.valid(phase.effect):return false
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
            events.append({"t":start,"kind":"vfx","anchor":a.anchor,"preset":phase.effect.duplicate(true)})
        # Contact pose is reached at the exact strike marker.
        keys.append({"t":end,"pose":phase.pose.duplicate(true)})
        if i==2:events.append({"t":end,"kind":"strike","anchor":a.anchor})
    events.sort_custom(func(x,y):return float(x.t)<float(y.t))
    return {"duration":phase_start(a,4),"loop":false,"keys":keys,"events":events}

static func load_profile(path: String=PATH) -> Dictionary:
    if FileAccess.file_exists(path):
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if valid(data):return data
    return defaults()

static func save_profile(a: Dictionary,path: String=PATH) -> bool:
    if not valid(a):return false
    var f:=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return false
    f.store_string(JSON.stringify(a,"  "))
    return true
