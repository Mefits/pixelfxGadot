extends "res://lab/impact_reactions_092.gd"
## Experimental grounded reaction policy. No launch, fall, or gameplay damage.
## 0: frozen 092 C; 1: predictive recovery; 2: predictive + artistic lean.
const WEIGHTS={"hips":.36,"chest":.33,"head":.15,"knee_near":.05,"knee_far":.05,"elbow_near":.03,"elbow_far":.03}
var variant:int
var momentum:float=0.
var prediction:float=0.
var margin:float=0.
var recoveries:int=0
var last_start:int=-1

func _init(r,p:Dictionary,m:int):
    super(r,p,2)
    variant=m

func hit(id:int,zone:String,dir:float,power:float)->bool:
    if not super.hit(id,zone,dir,power):return false
    # Translational intent independent of the joint recoil. Tunable proxy,
    # not mass/inertia calibrated from the static references.
    if variant>0:momentum=clampf(momentum+dir*65.*power*power,-155.,155.)
    return true

func center()->float:
    var value:float=0.
    for id in WEIGHTS:value+=rig.point(id).x*float(WEIGHTS[id])
    return value

func snapshot()->Dictionary:
    var s:Dictionary=super.snapshot()
    s.merge({"momentum":momentum,"prediction":prediction,"margin":margin,"recoveries":recoveries,"last_start":last_start})
    return s

func restore(s:Dictionary)->void:
    super.restore(s)
    momentum=float(s.momentum)
    prediction=float(s.prediction)
    margin=float(s.margin)
    recoveries=int(s.recoveries)
    last_start=int(s.last_start)

func step()->Dictionary:
    var elapsed:int=step_age
    var sample:Dictionary=super.step()
    if variant==2 and elapsed>=0:
        # Reference 1: shoulders and head lag behind the hips, free arms
        # move forward later. The planted foot remains an exact IK goal.
        var t:float=float(elapsed)
        var lean:float=smoothstep(0.,7.,t)*(1.-smoothstep(9.,24.,t))
        var arms:float=smoothstep(3.,11.,t)*(1.-smoothstep(12.,24.,t))
        var p:Dictionary=sample.pose
        p.angles.hips+=direction*9.*lean
        p.angles.chest+=direction*15.*lean
        p.angles.head+=direction*5.*lean
        p.angles.shoulder_near+=direction*10.*arms
        p.angles.shoulder_far+=direction*17.*arms
        p.angles.elbow_near-=direction*12.*arms
        p.angles.elbow_far-=direction*18.*arms
        var desired:Vector2=IK.root_of(p)+Vector2(direction*1.2*lean,.45*lean)
        Recovery.project_root(rig,p,desired,anchors)
        for side in Leg.SIDES:IK.solve_leg(rig,p,side,anchors[side],1.)
        rig.evaluate(p)
        sample.error=0.
        for side in Leg.SIDES:sample.error=maxf(sample.error,rig.point("foot_"+side).distance_to(anchors[side]))
    var lo:float=minf(anchors.near.x,anchors.far.x)
    var hi:float=maxf(anchors.near.x,anchors.far.x)
    prediction=center()+momentum*.11
    margin=minf(prediction-lo,hi-prediction)
    # Trigger from projected position and actual base, not a scripted hit
    # number. No automatic launch; the game must authorize that separately.
    if variant>0 and elapsed<0 and step_age<0 and margin<0. and absf(momentum)>15.:
        var dir:float=-1. if prediction<lo else 1.
        if permit_recovery_step(dir):
            recoveries+=1
            last_start=tick-1
            to_ankle=from_ankle+Vector2(dir*clampf(4.5-margin*.18,4.5,5.8),0.)
            momentum*=.35
    momentum*=.86
    sample["prediction"]=prediction
    sample["margin"]=margin
    sample["recoveries"]=recoveries
    sample["last_start"]=last_start
    return sample
