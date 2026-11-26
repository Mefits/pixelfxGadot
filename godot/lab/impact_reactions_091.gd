extends RefCounted
## Isolated R&D reaction layer, not the Astra kernel or a rigid-body solver.
## Fixed tick; angular spring velocities are stylized impulse proxies.
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const Recovery=preload("res://lab/stance_recovery_078.gd")
const DT:float=1./60.
const CHANNELS=["hips","chest","head","shoulder_near","shoulder_far","elbow_near","elbow_far","rx","ry"]
const LIMITS=[12.,30.,35.,32.,32.,25.,25.,2.8,2.8]
const STIFFNESS=[140.,170.,215.,95.,95.,105.,105.,150.,180.]
const DAMPING=[22.,23.,25.,15.,15.,17.,17.,24.,25.]
var rig
var base:Dictionary
var anchors:Dictionary={}
var mode:int
var x:Array=[]
var v:Array=[]
var active:Array=[]
var seen:Array=[]
var tick:int=0

func _init(r,p:Dictionary,m:int):
    rig=r
    mode=m
    base=Leg.sanitize(p)
    # Preserve the source ankle locations, give the nearly extended knees
    # working slack. Identical guard in every lane.
    rig.evaluate(base)
    for side in Leg.SIDES:anchors[side]=rig.point("foot_"+side)
    base.root[1]=float(base.root[1])+2.4
    for side in Leg.SIDES:IK.solve_leg(rig,base,side,anchors[side],1.)
    for i in CHANNELS.size():
        x.append(0.)
        v.append(0.)

func snapshot()->Dictionary:
    return {"x":x.duplicate(),"v":v.duplicate(),"active":active.duplicate(true),"seen":seen.duplicate(),"tick":tick}

func restore(s:Dictionary)->void:
    x=s.x.duplicate()
    v=s.v.duplicate()
    active=s.active.duplicate(true)
    seen=s.seen.duplicate()
    tick=int(s.tick)

func hit(id:int,zone:String,direction:float,power:float)->bool:
    if seen.has(id):return false
    if not zone in ["HEAD","BODY"] or absf(direction)!=1. or power<=0. or power>1.6:return false
    seen.append(id)
    # Direction is signed horizontal push, zone is supplied by an external
    # contact system. No invented collision, HP or hitstun in this test.
    var h:bool=zone=="HEAD"
    var target:Array=[7.,14.,24.,-19.,-13.,17.,12.,1.8,1.1] if h else [4.,-24.,9.,-25.,-20.,-8.,-5.,1.2,2.0]
    var velocity:Array=[145.,290.,610.,-380.,-290.,330.,260.,40.,27.] if h else [90.,-560.,170.,-510.,-430.,-170.,-110.,32.,45.]
    for i in CHANNELS.size():
        var sign:float=1. if i==8 else direction
        target[i]=float(target[i])*power*sign
        if mode!=0:v[i]=clampf(float(v[i])+float(velocity[i])*power*sign,-1000. if i<7 else -75.,1000. if i<7 else 75.)
    if mode!=1:active.append({"start":tick,"target":target,"zone":zone})
    return true

func step()->Dictionary:
    # Bounded semi-implicit damped spring; no wall-clock inputs.
    for i in CHANNELS.size():
        v[i]=float(v[i])+(-float(STIFFNESS[i])*float(x[i])-float(DAMPING[i])*float(v[i]))*DT
        var next:float=float(x[i])+float(v[i])*DT
        x[i]=clampf(next,-float(LIMITS[i]),float(LIMITS[i]))
        if x[i]!=next:v[i]=0.
    var authored:Array=[]
    for i in CHANNELS.size():authored.append(0.)
    var remaining:Array=[]
    for event in active:
        var age:float=float(tick-int(event.start)+1)
        # Authored accent at 4 ticks, complete ease-out by 26 ticks.
        # Overlapping events sum, rather than resetting a previous clip.
        var delay:float=0.
        for i in CHANNELS.size():
            delay=2. if i in [3,4,5,6] else (1. if i==0 else 0.)
            var t:float=age-delay
            var envelope:float=smoothstep(0.,4.,t)*(1.-smoothstep(4.,26.,t))
            authored[i]+=float(event.target[i])*envelope
        if age<28.:remaining.append(event)
    active=remaining
    var p:Dictionary=base.duplicate(true)
    var offset:Array=[]
    for i in CHANNELS.size():
        var d:float=float(authored[i]) if mode==0 else (float(x[i]) if mode==1 else .45*float(authored[i])+.85*float(x[i]))
        d=clampf(d,-float(LIMITS[i]),float(LIMITS[i]))
        offset.append(d)
        if i<7:p.angles[CHANNELS[i]]=float(p.angles[CHANNELS[i]])+d
    var desired:Vector2=IK.root_of(base)+Vector2(offset[7],offset[8])
    # Shared support constraint across all modes. No horizontal world motor.
    Recovery.project_root(rig,p,desired,anchors)
    for side in Leg.SIDES:IK.solve_leg(rig,p,side,anchors[side],1.)
    rig.evaluate(p)
    var error:float=0.
    for side in Leg.SIDES:error=maxf(error,rig.point("foot_"+side).distance_to(anchors[side]))
    tick+=1
    return {"pose":p,"offset":offset,"error":error,"accepted":seen.size(),"energy_proxy":v.duplicate()}
