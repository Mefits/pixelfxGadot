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
        p.root=[0.,-1.]
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
        support.resolve(p,[{"toe":Vector2(5.,0.),"pitch":0.,"stance":true},{"toe":Vector2(-3.,0.),"pitch":0.,"stance":true}])
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
    defaults[id]=d.duplicate(true)
    return d

static func breathing_doc(stance:Dictionary)->Dictionary:
    # Five sparse, smoothly interpolated poses. The compression starts
    # at the pelvis; chest and arms peak slightly later. Same foot anchors.
    var start:Dictionary=stance.keys[0]
    var keys:Array=[]
    var duration:float=2.4
    var phases:Array=[0.,.30,.58,.80,1.]
    var lift:Array=[0.,.65,1.,.30,0.]
    var chest:Array=[0.,.45,1.,.50,0.]
    var arms:Array=[0.,.15,1.,.65,0.]
    var rear:Array=[0.,.40,.85,1.,0.]
    for i in phases.size():
        var p:Dictionary={"angles":start.angles.duplicate(true),"root":start.root.duplicate()}
        p.root[1]+=.9*lift[i]
        p.angles.hips-=.9*lift[i]
        p.angles.chest-=2.2*chest[i]
        p.angles.head+=1.5*arms[i]
        p.angles.shoulder_turn-=2.5*chest[i]
        p.angles.shoulder_near-=5.5*arms[i]
        p.angles.elbow_near+=7.5*arms[i]
        p.angles.shoulder_far+=4.5*rear[i]
        p.angles.elbow_far-=7.*rear[i]
        keys.append(key(phases[i]*duration,p))
    return {"version":2,"id":"walk_breathe","name":"Idle · дыхание","kind":"action","walk_role":"walk_breathe","duration":duration,"fps":60,"easing":"smooth","loop":true,"keys":keys,"goals":[],"events":[]}

static func document(id:String)->Dictionary:
    var saved:Dictionary=Asset.read(Asset.FOLDER+id+".json")
    if saved.get("id")==id and saved.get("walk_role")==id and Asset.problem(saved)=="":return Asset.normalise(saved)
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
    return {"doc":d,"contacts":contacts,"fixed":fixed}

static func intent(program:Dictionary,phase:float,rig)->Dictionary:
    var d:Dictionary=program.doc
    phase=fposmod(phase,1.) if d.loop else 0.
    var p:Dictionary=sample(d,phase)
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
    return {"pose":p,"paths":paths}

static func resolve(rig,support,value:Dictionary)->Dictionary:
    var p:Dictionary=value.pose.duplicate(true)
    Grid.pose(p)
    support.resolve(p,value.paths)
    return p
