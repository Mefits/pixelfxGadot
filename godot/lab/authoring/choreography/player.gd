extends RefCounted
## Receiver for the optional spatial track of an M action. Coordinates are rig units.
const Asset=preload("../asset.gd")
const Clips=preload("res://addons/creature/clips.gd")
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const TRACK=["yaw","chest","shoulders","z","azimuth","weight","gx","gy","gz"]
var rig=FK.new()
var desired=FK.new()
var solver=Support.new()
var entry
var effector:String
var target_error:float
var frames:Array=[]
var markers:Array=[]
var signature:String
var art:Dictionary
var current:Dictionary
var previous:Dictionary
var tick:int
var age:int
var serial:int
var slot:int
var side:String
var events:Array=[]
var offset:Vector3
var phase:String

static func problem(d:Dictionary)->String:
    var error:=Asset.problem(d)
    if error!="":return error
    if not d.goals.is_empty() or not d.get("release",{}).is_empty() or d.get("loop",false):return "Пространственный клип использует собственные цели и опоры"
    if d.get("spatial_version")!=1 or d.kind!="action" or d.get("fps")!=60:return "Нужен пространственный документ 60 Гц"
    if not d.get("effector") in ["foot_near","foot_far","hand_near","hand_far"]:return "Конечность"
    var last:=-1
    for k in d.keys:
        if not k.has("root") or not k.get("easing") in Asset.EASING:return "Корень или кривая фазы"
        var s=k.get("space")
        if not s is Dictionary or not s.get("support") in ["near","far","air"] or not s.get("phase") is String:return "Фаза или опора"
        for channel in TRACK:
            if not Asset.number(s.get(channel),-1440.,1440.):return "Канал "+channel
        if not Asset.number(s.weight,0.,1.):return "Вес цели"
        var tick:=roundi(k.t*60.)
        if tick<=last:return "Ключи совпадают в одном такте"
        last=tick
    return ""

# JSON decimal seconds can round differently in Godot 4.4. The spatial
# clock stores integral ticks; canonicalize only these fields for identity.
static func timeline_document(d:Dictionary)->Dictionary:
    var value:=Asset.normalise(d)
    value.duration=roundi(value.duration*60.)
    for key in value.keys:key.t=roundi(key.t*60.)
    for marker in value.events:marker.t=roundi(marker.t*60.)
    return value

func start(d:Dictionary,now:Dictionary,prior:Dictionary,instance:int,fighter:int=0)->bool:
    if problem(d)!="":return false
    signature=JSON.stringify(timeline_document(d),"",true,true).sha256_text()
    effector=d.effector
    serial=instance
    slot=fighter
    entry=Entry.new(now,prior)
    current=now
    previous=prior
    Entry.write_exact(rig,now)
    solver.contacts.clear()
    side=""
    age=-1
    tick=0
    offset=Vector3.ZERO
    frames.clear()
    markers=d.events.duplicate(true)
    var clip={"duration":d.duration,"loop":false,"keys":[]}
    for k in d.keys:
        clip.keys.append({"t":k.t,"pose":{"angles":k.angles,"root":k.root},"easing":k.easing})
    var index:=0
    for i in roundi(d.duration*60.)+1:
        while index+1<d.keys.size() and roundi(d.keys[index+1].t*60.)<=i:index+=1
        var a:Dictionary=d.keys[index]
        var b:Dictionary=d.keys[mini(index+1,d.keys.size()-1)]
        var u:=clampf((i/60.-a.t)/maxf(.00001,b.t-a.t),0.,1.)
        match b.easing:
            "smooth":u=smoothstep(0.,1.,u)
            "accelerate":u=pow(u,2.15)
            "hold","snap":u=0.
        var frame:=Clips.sample(clip,i/60.,false)
        frame.space=a.space.duplicate()
        for channel in TRACK:frame.space[channel]=lerpf(a.space[channel],b.space[channel],u)
        frames.append(frame)
    return true

func step(_cmd:Dictionary={})->bool:
    if age+1>=frames.size():return false
    age+=1
    var k:Dictionary=frames[age]
    var s:Dictionary=k.space
    phase=s.phase
    art=entry.current.pose.duplicate(true)
    art.angles.merge(k.angles,true)
    art.root=k.root.duplicate()
    var yaw:int=entry.current.yaw+roundi(s.yaw*FK.TURN/360.)
    desired.evaluate_spatial(art,yaw,s.z,roundi(s.chest*FK.TURN/360.),roundi(s.shoulders*FK.TURN/360.),{"thigh_near":roundi(s.azimuth*FK.TURN/360.)})
    aim(s)
    if age==0:offset=Vector3(entry.current.root)-desired.point3("hips")
    for id in desired.joint_xyz:desired.joint_xyz[id]+=offset
    Entry.update_xy(desired)
    if age<6:art=entry.blend(desired,Entry.sample(desired,art),age,6)
    var requested:String=s.support
    # Chaining in flight keeps both feet free until a toe approaches ground.
    if entry.current.contacts.is_empty() and age<6 and minf(absf(Support.toe(desired,art,"near").y),absf(Support.toe(desired,art,"far").y))>1.:
        requested="air"
    if side!=requested:
        solver.contacts.clear()
        side=requested
        if side!="air":
            solver.capture(desired,art,side,Support.PIVOT)
            var anchor:Vector3=solver.contacts[side].anchor
            if age==0:anchor=entry.current.toes[side]
            else:anchor.y=0.
            solver.contacts[side].anchor=anchor
    # Ground is a unilateral constraint: only a penetrating free toe gets a
    # temporary floor target, without acquiring a persistent support anchor.
    if not solver.resolve_evaluated(rig,desired,32.).accepted:return false
    var temporary:Array=[]
    for foot in Support.SIDES:
        if foot==side:continue
        var toe:=Support.toe(rig,art,foot)
        if toe.y>.001:
            solver.capture(rig,art,foot,Support.FIXED)
            solver.contacts[foot].anchor=Vector3(toe.x,0.,toe.z)
            temporary.append(foot)
    if not temporary.is_empty():
        if not solver.resolve_evaluated(rig,rig,32.).accepted:return false
        for foot in temporary:solver.contacts.erase(foot)
    tick=age+1
    previous=current
    current=Entry.sample(rig,art,solver)
    events=[]
    for i in markers.size():
        var m:Dictionary=markers[i]
        if roundi(m.t*60.)==age:
            events.append({"id":[slot,serial,i],"tick":age,"kind":m.kind,"joint":m.anchor,"xyz":rig.point3(m.anchor)})
    return true

# Target offsets are in the entry heading frame, relative to the proximal joint.
func aim(s:Dictionary)->void:
    target_error=0.
    if s.weight==0.:return
    var limb:String=effector.get_slice("_",1)
    if effector.begins_with("foot") and s.support==limb:return
    var leg:=effector.begins_with("foot")
    var h:=("thigh_" if leg else "shoulder_")+limb
    var k:=("knee_" if leg else "elbow_")+limb
    var hip:Vector3=desired.point3(h)
    var ray:Vector3=desired.point3(effector)-hip
    var goal:Vector3=hip+FK.yaw_basis(entry.current.yaw)*Vector3(s.gx,s.gy,s.gz)
    var target:=desired.point3(effector).lerp(goal,s.weight)
    # Interpolate direction and extension separately; a Cartesian blend of
    # opposing rays would pass through the hip and violate minimum bend.
    var aim_ray:=goal-hip
    if ray.length_squared()>.000001 and aim_ray.length_squared()>.000001:
        target=hip+Entry.blend_direction(ray.normalized(),aim_ray.normalized(),s.weight)*lerpf(ray.length(),aim_ray.length(),s.weight)
    var q:=Support.IK.solve(hip,target,desired.rest_offset_xyz(k).length(),desired.rest_offset_xyz(effector).length(),ray.normalized(),desired.point3(k)-hip)
    target_error=q.residual
    var upper:Vector3=q.knee-hip
    var lower:Vector3=q.ankle-q.knee
    var normal:=upper.cross(lower).normalized()
    desired.joint_xyz[k]=q.knee
    desired.joint_xyz[effector]=q.ankle
    desired.joint_basis[h]=Support.IK.bone_frame(desired.rest_offset_xyz(k),upper,normal)
    desired.joint_basis[k]=Support.IK.bone_frame(desired.rest_offset_xyz(effector),lower,normal)

func save()->PackedByteArray:
    return var_to_bytes([signature,serial,slot,age,side,offset,entry.current,entry.previous,current,previous,solver.contacts,events])

func restore(bytes:PackedByteArray)->bool:
    var s=bytes_to_var(bytes)
    if not s is Array or s.size()!=12 or s[0]!=signature:return false
    serial=s[1]
    slot=s[2]
    age=s[3]
    tick=age+1
    side=s[4]
    offset=s[5]
    entry=Entry.new(s[6],s[7])
    current=s[8]
    previous=s[9]
    solver.contacts=s[10]
    events=s[11]
    art=current.pose
    phase=frames[maxi(0,age)].space.phase
    Entry.write_exact(rig,current)
    return true
