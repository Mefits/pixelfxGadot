extends RefCounted
const Common=preload("res://lab/ragdoll_common_099c.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const PROFILES=[{"accent":.55,"hold":.20,"hitstop":2,"release":.19,"motor":1.},{"accent":1.,"hold":.30,"hitstop":4,"release":.19,"motor":1.},{"accent":1.45,"hold":.40,"hitstop":6,"release":.19,"motor":1.}]
var model
var world
var n:int
var settings:Dictionary={}
var profile:int=1
var age:int=-1
var tick:int=0
var event_count:int=0
var pinned:bool=false
var generation:int=0

func setup(p:int=1,passes:int=8,material:int=1)->bool:
    world=null
    generation+=1
    if not ClassDB.class_exists("MotionPhysics099D"):return false
    if p<0 or p>2 or not passes in [8,12,16] or not material in [0,1]:return false
    return setup_model(Common.make_model(),p,passes,material)

# Also used by the live handoff adapter; supplied model is isolated from Astra.
func setup_model(entry_model,p:int=1,passes:int=8,material:int=1)->bool:
    world=null
    generation+=1
    if not ClassDB.class_exists("MotionPhysics099D") or p<0 or p>2 or not passes in [8,12,16] or not material in [0,1]:return false
    model=entry_model
    n=model.bodies.size()
    profile=p
    settings=PROFILES[p].duplicate(true)
    age=-1
    tick=0
    event_count=0
    pinned=false
    var candidate=ClassDB.instantiate("MotionPhysics099D")
    if not candidate.setup(Common.specification(model),passes,1,material):return false
    for i in n:
        var b:Dictionary=model.bodies[i]
        if not candidate.set_velocity(i,b.v,b.w):return false
    world=candidate
    return true

func lower(id:String)->bool:
    return id=="hips" or id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_")

func set_pinned(value:bool)->bool:
    if world==null:return false
    if pinned==value:return true
    for i in n:
        if lower(model.bodies[i].id):
            if not world.set_kinematic(i,value):return false
            if value and not world.set_velocity(i,Vector2.ZERO,0.):return false
    pinned=value
    return true

func hit(id:String,direction:Vector2,power:float,parameters:Dictionary)->bool:
    if world==null or not model.ids.has(id) or (pinned and lower(id)):return false
    if not direction.is_finite() or direction.length_squared()<.001 or not is_finite(power) or power<.1 or power>2.:return false
    for key in ["accent","hold","release","motor","hitstop"]:
        if not parameters.has(key) or not is_finite(float(parameters[key])):return false
    if parameters.accent<0. or parameters.accent>2. or parameters.hold<.05 or parameters.hold>.6 or parameters.release<.05 or parameters.release>.5 or parameters.motor<0. or parameters.motor>1. or parameters.hitstop<0 or parameters.hitstop>12:return false
    Common.load_state(model,world.state())
    var i:int=model.ids[id]
    var b:Dictionary=model.bodies[i]
    var point:Vector2=Vector2(b.p)+Vector2(0.,-1.5).rotated(float(b.a))
    var impulse:Vector2=direction.normalized()*Vector2(Common.event(model).impulse).length()*power
    if not world.impulse(i,impulse,point):return false
    settings=parameters.duplicate(true)
    age=0
    event_count+=1
    return true

func step()->bool:
    if world==null:return false
    # Preserve the guard until the first user event; no pre-hit ragdoll drift.
    if age<0:return true
    if not art_step(world,age,profile):return false
    age+=1
    tick+=1
    return true

func pose()->Dictionary:
    Common.load_state(model,world.state())
    return model.pose()

func snapshot()->Dictionary:
    return {"generation":generation,"age":age,"tick":tick,"event_count":event_count,"pinned":pinned,"settings":settings.duplicate(true),"native":world.snapshot(),"hash":world.state_hash()}

func restore(s:Dictionary)->bool:
    # Trusted local snapshot from this controller/world only.
    if world==null or s.get("generation")!=generation:return false
    if not world.restore(s.native):return false
    age=s.age
    tick=s.tick
    event_count=s.event_count
    pinned=s.pinned
    settings=s.settings.duplicate(true)
    return world.state_hash()==s.hash

func controls(t:int,copies:int=1,profile:int=1)->PackedFloat64Array:
    var a:=PackedFloat64Array()
    a.resize(n*copies)
    var sec:float=float(t)/120.
    for i in a.size():
        var id:String=model.bodies[i%n].id
        var w:float=0.
        if profile==0:
            w=1.-smoothstep(.06,.24,sec)
        elif id=="chest":
            w=1. if sec<=.28 else lerpf(1.,.12,smoothstep(.28,.48,sec))
        elif id=="head":
            w=.85 if sec<=.26 else lerpf(.85,.12,smoothstep(.26,.46,sec))
        elif id.begins_with("thigh_"):
            w=1. if sec<=.30 else lerpf(1.,.20,smoothstep(.30,.54,sec))
        elif id.begins_with("knee_"):
            w=.92 if sec<=.30 else lerpf(.92,.24,smoothstep(.30,.52,sec))
        elif id.begins_with("shoulder_"):
            w=.82 if sec<=.20 else lerpf(.82,.10,smoothstep(.20,.42,sec))
        elif id.begins_with("elbow_"):
            w=.72 if sec<=.20 else lerpf(.72,.08,smoothstep(.20,.40,sec))
        elif id.begins_with("hand_"):
            w=.42 if sec<=.16 else lerpf(.42,.04,smoothstep(.16,.36,sec))
        elif id.begins_with("foot_"):
            w=.36 if sec<=.26 else lerpf(.36,.08,smoothstep(.26,.48,sec))
        a[i]=w
    return a
# Artistic inputs are calculated from profile and integer event age only.
# Hitstop freezes the local experiment world; integration must share this clock.
func freeze_ticks(profile:int)->int:
    return int(settings.hitstop)
func art_targets(t:int,profile:int)->PackedFloat64Array:
    var a:=PackedFloat64Array()
    a.resize(n)
    var age:float=maxf(0.,float(t-freeze_ticks(profile))/120.)
    var strength:float=settings.accent
    var hold:float=settings.hold
    var accent:float=smoothstep(0.,.055,age)*(1.-smoothstep(hold,hold+.16,age))
    for i in n:
        var b:Dictionary=model.bodies[i]
        var id:String=b.id
        var shift:float=0.
        if id=="chest":shift=-18.
        elif id=="head":shift=12.
        elif id.begins_with("thigh_"):shift=-22.
        elif id.begins_with("knee_"):shift=18.
        elif id.begins_with("shoulder_"):shift=32.
        elif id.begins_with("elbow_"):shift=-20.
        var lag:float=1.
        if id.begins_with("thigh_") or id.begins_with("knee_"):lag=smoothstep(.025,.10,age)
        a[i]=clampf(float(b.goal)+deg_to_rad(shift*strength*accent*lag),float(b.lo),float(b.hi))
    return a
func art_step(w,t:int,profile:int,copies:int=1)->bool:
    if t<freeze_ticks(profile):return true
    var age:int=t-freeze_ticks(profile)
    var hold:float=settings.hold
    var a:PackedFloat64Array=controls(age, copies,1)
    var release:float=smoothstep(hold,hold+float(settings.release),float(age)/120.)
    for i in a.size():
        var id:String=model.bodies[i%n].id
        if id=="chest" or id.begins_with("thigh_") or id.begins_with("knee_"):
            a[i]=lerpf(1.,.12,release)
        elif id=="head" or id.begins_with("shoulder_") or id.begins_with("elbow_"):
            a[i]=lerpf(.90,.08,release)
    for i in a.size():a[i]*=float(settings.motor)
    return w.step_art(a,art_targets(t,profile))
