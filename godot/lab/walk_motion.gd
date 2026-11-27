extends RefCounted
## Editable locomotion documents. No changes to Astra's accepted runtime.
const Asset=preload("res://lab/authoring/asset.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Gait=preload("res://lab/hybrid091/gait.gd")
const Support=preload("res://lab/hybrid091/support.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const STRIDE:float=32.
const CONTACT:float=18.24/32.
const SIDES=["near","far"]
const GUARD_REVISION:int=4
const IDLE_DURATION:float=2.0
static var defaults:Dictionary={}

static func key(t:float,p:Dictionary)->Dictionary:
    var angles:Dictionary={}
    for id in Asset.CHANNELS+Asset.LEG_CHANNELS:angles[id]=float(p.angles.get(id,0.))
    return {"t":t,"angles":angles,"root":p.root.duplicate()}

static func default_doc(id:String)->Dictionary:
    if id=="walk_breathe":return breathing_doc(document("walk_idle"))
    if defaults.has(id):return defaults[id].duplicate(true)
    var rig=Body.make_rig()
    var gait=Gait.new(rig,Asset.read(Asset.FIX+"run053a_C.json").payload.clip)
    var support=Support.new(rig)
    var keys:Array=[]
    var idle:bool=id=="walk_idle"
    var backward:bool=id=="walk_backward"
    var duration:float=.1 if idle else 64./60.
    if idle:
        var p:Dictionary=gait.intent().pose
        p.root=[0.,.35]
        p.angles.hips=2.
        p.angles.chest=0.
        p.angles.head=-2.
        p.angles.pelvis_turn=45.
        # Side-on asymmetric guard. Both forearms point upwards, with the
        # near fist forward and the far fist close to the chin.
        p.angles.shoulder_turn=32.
        p.angles.shoulder_near=-17.
        p.angles.shoulder_far=-53.
        p.angles.elbow_near=-134.
        p.angles.elbow_far=-124.
        support.resolve(p,[{"toe":Vector2(7.,0.),"pitch":0.,"stance":true},{"toe":Vector2(-5.,0.),"pitch":0.,"stance":true}])
        keys.append(key(0.,p))
    else:
        for index in 9:
            var phase:float=float(index)/8.
            var local:float=fposmod((1.-phase if backward else phase)*STRIDE,STRIDE)
            var q:float=floorf(local/16.)*16.
            var side:int=int(q/16.)
            gait.travel=local
            gait.velocity=1.
            gait.side=side
            gait.queue=[q,q+16.,q+32.]
            gait.legs[side]={"start":q,"end":q+32.}
            gait.legs[1-side]={"start":q-16.,"end":q+16.}
            var intent:Dictionary=gait.intent()
            var p:Dictionary=intent.pose
            support.resolve(p,intent.paths)
            keys.append(key(phase*duration,p))
    var label:String="Стойка" if idle else ("Ходьба назад" if backward else "Ходьба вперёд")
    var d:Dictionary={"version":2,"id":id,"name":label,"kind":"action","walk_role":id,"duration":duration,"fps":60,"easing":"linear","loop":not idle,"keys":keys,"goals":[],"events":[]}
    if idle:d.guard_revision=GUARD_REVISION
    defaults[id]=d.duplicate(true)
    return d

# Continuous guard controller. The two grounded toes define the support span.
# The phase commands a weight distribution, not simulated reaction forces.
# All angles and root offsets are relative to the unchanged authored guard.
static func guard_pose(base:Dictionary,phase:float)->Dictionary:
    var u:float=fposmod(phase,1.)
    var transfer:float=sin(TAU*u)
    var compression:float=pow(sin(PI*u),2.)
    var near_unload:float=pow(maxf(0.,-transfer),2.)
    var far_unload:float=pow(maxf(0.,transfer),2.)
    var p:Dictionary={"angles":base.angles.duplicate(true),"root":base.root.duplicate()}
    p.root[0]+=.7*transfer
    # Small breathing compression and barely perceptible heel unloading.
    p.root[1]+=.30*compression+.12*transfer*transfer
    p.angles.foot_pitch_near+=2.*near_unload
    p.angles.foot_pitch_far+=2.*far_unload
    p.angles.hips+=.45*transfer-.25*compression
    p.angles.chest-=1.1*compression+.45*transfer
    p.angles.head+=.4*compression+.15*transfer
    p.angles.shoulder_turn-=.7*compression
    p.angles.shoulder_near-=2.2*compression+.7*far_unload
    p.angles.elbow_near+=2.6*compression+.7*far_unload
    p.angles.shoulder_far+=1.8*compression+.7*near_unload
    p.angles.elbow_far-=2.3*compression+.9*near_unload
    return p

static func breathing_doc(stance:Dictionary)->Dictionary:
    # Editor key snapshots are editable. An unmodified set is evaluated
    # continuously; intentionally edited keys use the authored sampler.
    var start:Dictionary=stance.keys[0]
    var keys:Array=[]
    for i in 5:
        var phase:float=float(i)/4.
        keys.append(key(phase*IDLE_DURATION,guard_pose(start,phase)))
    return {"version":2,"guard_revision":GUARD_REVISION,"guard_procedural":true,"id":"walk_breathe","name":"Idle · динамическая опора","kind":"action","walk_role":"walk_breathe","duration":IDLE_DURATION,"fps":60,"easing":"smooth","loop":true,"keys":keys,"goals":[],"events":[]}

static func procedural_guard(d:Dictionary)->bool:
    if not d.get("guard_procedural",false) or not d.get("loop",false) or d.keys.size()!=5 or d.easing!="smooth":return false
    for i in 5:
        var k:Dictionary=d.keys[i]
        var phase:float=float(i)/4.
        if not is_equal_approx(float(k.t),phase*float(d.duration)) or k.get("easing",d.easing)!="smooth":return false
        var expected:Dictionary=guard_pose(d.keys[0],phase)
        for channel in expected.angles:
            if not is_equal_approx(float(k.angles.get(channel,INF)),float(expected.angles[channel])):return false
        for axis in 2:
            if not is_equal_approx(float(k.root[axis]),float(expected.root[axis])):return false
    return true

# One-time upgrade of the two bound guard slots. Retain the original bytes
# in a separate directory; a failed archive leaves the old file untouched.
static func archive_guard(id:String)->bool:
    var source:String=Asset.FOLDER+id+".json"
    if not FileAccess.file_exists(source):return true
    var folder:String="user://motion_authoring_backup/"
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:return false
    var target:String=folder+id+"_before_guard_v"+str(GUARD_REVISION)+".json"
    var suffix:int=1
    while FileAccess.file_exists(target):
        target=folder+id+"_before_guard_v"+str(GUARD_REVISION)+"_"+str(suffix)+".json"
        suffix+=1
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(target))==OK

static func document(id:String)->Dictionary:
    var saved:Dictionary=Asset.read(Asset.FOLDER+id+".json")
    var guard_slot:bool=id in ["walk_idle","walk_breathe"]
    if guard_slot and FileAccess.file_exists(Asset.FOLDER+id+".json") and int(saved.get("guard_revision",0))<(2 if id=="walk_idle" else GUARD_REVISION):
        if archive_guard(id):
            return default_doc(id)
    if saved.get("id")==id and saved.get("walk_role")==id and Asset.problem(saved)=="":
        var d:Dictionary=Asset.normalise(saved)
        if id=="walk_idle":d.guard_revision=GUARD_REVISION
        if id=="walk_breathe":d.loop=true
        return d
    return default_doc(id)

static func sample(d:Dictionary,phase:float)->Dictionary:
    var keys:Array=[]
    for k in d.keys:
        keys.append({"t":k.t,"pose":{"angles":k.angles,"root":k.root},"easing":k.get("easing",d.easing)})
    return Clips.sample({"duration":d.duration,"keys":keys,"loop":d.loop,"easing":d.easing},phase*float(d.duration),false)

static func toe(rig,p:Dictionary,side:String)->Vector2:
    return Vector2(rig.point("foot_"+side))+IK.toe_vector(p,side)

static func toes(rig,p:Dictionary)->Array:
    rig.evaluate(p)
    return [toe(rig,p,"near"),toe(rig,p,"far")]

static func contact_start(d:Dictionary,index:int)->float:
    var offset:float=.5*index
    if d.walk_role=="walk_backward":offset=1.-CONTACT-offset
    return fposmod(offset,1.)

# Precompute the authored touchdown and liftoff endpoints. Runtime uses a
# world-fixed stance target and a continuous correction on the swing arc.
static func prepare(d:Dictionary,stance:Dictionary={})->Dictionary:
    var rig=Body.make_rig()
    var contacts:Array=[]
    for i in 2:
        var c:float=contact_start(d,i)
        var start:Vector2=toes(rig,sample(d,c))[i]
        var end:Vector2=toes(rig,sample(d,fposmod(c+CONTACT,1.)))[i]
        contacts.append({"phase":c,"start":start,"end":end})
    var fixed:Array=[]
    if d.walk_role=="walk_breathe":
        var base:Dictionary=stance if not stance.is_empty() else document("walk_idle")
        fixed=toes(rig,sample(base,0.))
    return {"doc":d,"contacts":contacts,"fixed":fixed,"procedural":d.walk_role=="walk_breathe" and procedural_guard(d)}

static func intent(program:Dictionary,phase:float,rig)->Dictionary:
    var d:Dictionary=program.doc
    phase=fposmod(phase,1.) if d.loop else 0.
    var p:Dictionary=guard_pose(d.keys[0],phase) if program.get("procedural",false) else sample(d,phase)
    var points:Array=toes(rig,p)
    var paths:Array=[]
    for i in 2:
        var point:Vector2=points[i]
        var pitch:float=p.angles["foot_pitch_"+SIDES[i]]
        var stance:bool=true
        if d.walk_role in ["walk_idle","walk_breathe"]:
            if d.walk_role=="walk_breathe":point=program.fixed[i]
            point.y=0.
        else:
            var c:Dictionary=program.contacts[i]
            var u:float=fposmod(phase-float(c.phase),1.)
            var signed_stride:float=STRIDE*(-1. if d.walk_role=="walk_backward" else 1.)
            var planted_x:float=c.start.x-signed_stride*minf(u,CONTACT)
            stance=u<CONTACT
            if stance:
                point=Vector2(planted_x,0.)
            else:
                var blend:float=smoothstep(CONTACT,1.,u)
                var correction_start:float=c.start.x-signed_stride*CONTACT-c.end.x
                point.x+=lerpf(correction_start,0.,blend)
                # Ground continuity at contact boundaries.
                var envelope:float=smoothstep(CONTACT,CONTACT+.06,u)*(1.-smoothstep(.94,1.,u))
                point.y=minf(0.,point.y)*envelope
        paths.append({"toe":Grid.point(point),"pitch":Grid.scalar(pitch),"stance":stance})
    var value:Dictionary={"pose":p,"paths":paths}
    if d.walk_role in ["walk_idle","walk_breathe"]:
        # A kinematic load proxy over the actual support span, with both toes
        # remaining in contact. No binary switch or change of foot identity.
        var span:float=Vector2(paths[0].toe).x-Vector2(paths[1].toe).x
        var near_load:float=.5
        if absf(span)>.01:
            near_load=clampf(.5+(float(p.root[0])-float(d.keys[0].root[0]))/span,.12,.88)
        value["support_load"]=[near_load,1.-near_load]
    return value

static func resolve(rig,support,value:Dictionary)->Dictionary:
    var p:Dictionary=value.pose.duplicate(true)
    Grid.pose(p)
    support.resolve(p,value.paths)
    return p
