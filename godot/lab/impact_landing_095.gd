extends "res://lab/impact_reactions_092.gd"
## 095: bounded support slip, folded flight and guided floor settling. Not combat balance. Right-facing rig;
## signed rearward push is -X. A/B/C share local hybrid reaction.
enum Severity {LIGHT, MEDIUM, HEAVY}
const STEP_DURATION=20
var severity:int=0
var state:String="GUARD"
var age:int=0
var ground_start:=Vector2.ZERO
var ground_feet:Dictionary={}
var rear:String=""
var front:String=""
var flight_position:=Vector2.ZERO
var flight_velocity:=Vector2.ZERO
var flight_entry:Dictionary={}
var flight_pose:Dictionary={}
var floor_y:float=0.
var clearance:float=0.
var support_count:int=2
var total_steps:int=0
var slip:float=0.
var landing_age:int=0
var landing_entry:Dictionary={}
var landing_vx:float=0.
var contact_x:float=0.
var contact_joint:String=""

func _init(r,p:Dictionary,m:int):
    super(r,p,1)
    severity=m
    rig.evaluate(base)
    floor_y=bottom()

func bottom()->float:
    # Coarse joint envelopes only, not mesh collision. Initial standing
    # floor calibrated to the same proxy. Used solely to end this preview.
    var y:float=-INF
    for side in Leg.SIDES:
        y=maxf(y,rig.point("foot_"+side).y+1.5)
        y=maxf(y,rig.point("knee_"+side).y+2.)
        y=maxf(y,rig.point("hand_"+side).y+2.5)
    return max(y,rig.point("hips").y+4.,rig.point("chest").y+4.,rig.point("head").y+4.)

func strike(id:int,zone:String,push:float,power:float,category:int)->bool:
    # Only rearward push and an initially grounded stationary test subject
    # in this experiment. Subsequent heavy impacts require a future policy.
    if category!=severity or push!=-1. or state=="AIR" or state=="CONTACT" or state=="FALL" or state=="DOWN" or state=="STEP":return false
    if not super.hit(id,zone,push,power):return false
    direction=push
    age=0
    if category==Severity.LIGHT:
        state="LOCAL"
    elif category==Severity.MEDIUM:
        state="STEP"
        ground_start=IK.root_of(base)
        ground_feet=anchors.duplicate(true)
        rear="near" if anchors.near.x<anchors.far.x else "far"
        front="far" if rear=="near" else "near"
        total_steps=0
        slip=0.
    else:
        state="LAUNCH"
    return true

func snapshot()->Dictionary:
    var s:Dictionary=super.snapshot()
    s.merge({"state":state,"age":age,"ground_start":ground_start,"ground_feet":ground_feet.duplicate(true),"rear":rear,"front":front,"flight_position":flight_position,"flight_velocity":flight_velocity,"flight_entry":flight_entry.duplicate(true),"flight_pose":flight_pose.duplicate(true),"floor_y":floor_y,"clearance":clearance,"support_count":support_count,"total_steps":total_steps,"slip":slip,"landing_age":landing_age,"landing_entry":landing_entry.duplicate(true),"landing_vx":landing_vx,"contact_x":contact_x,"contact_joint":contact_joint})
    return s

func restore(s:Dictionary)->void:
    super.restore(s)
    state=s.state
    age=int(s.age)
    ground_start=s.ground_start
    ground_feet=s.ground_feet.duplicate(true)
    rear=s.rear
    front=s.front
    flight_position=s.flight_position
    flight_velocity=s.flight_velocity
    flight_entry=s.flight_entry.duplicate(true)
    flight_pose=s.flight_pose.duplicate(true)
    floor_y=float(s.floor_y)
    clearance=float(s.clearance)
    support_count=int(s.support_count)
    total_steps=int(s.total_steps)
    slip=float(s.slip)
    landing_age=int(s.landing_age)
    landing_entry=s.landing_entry.duplicate(true)
    landing_vx=float(s.landing_vx)
    contact_x=float(s.contact_x)
    contact_joint=s.contact_joint

func ground_step()->void:
    var cycle:int=mini(floori(float(age)/STEP_DURATION),1)
    var local:float=float(age-cycle*STEP_DURATION)
    var u:float=clampf((local-2.)/14.,0.,1.)
    var progress:float=smoothstep(0.,1.,u)
    var lead:String=rear if cycle==0 else front
    var trailing:String=front if cycle==0 else rear
    anchors[lead]=Vector2(ground_feet[lead])+Vector2(-8.*progress,-3.4*16.*u*u*(1.-u)*(1.-u))
    anchors[trailing]=Vector2(ground_feet[trailing])+Vector2(-8. if cycle==1 else 0.,0.)
    var travel:float=4.*float(cycle)+4.*smoothstep(0.,float(STEP_DURATION),local)
    var dip:float=1.8*sin(PI*clampf(float(age)/40.,0.,1.))
    # Brief shared support slip; two original swing arcs survive.
    slip=2.4*smoothstep(0.,7.,float(age))
    for side in Leg.SIDES:anchors[side]=Vector2(anchors[side])-Vector2(slip,0.)
    base.root=[ground_start.x-travel-slip,ground_start.y+dip]
    support_count=1 if u>0. and u<1. else 2
    moving=lead
    if local>=16.:total_steps=cycle+1

func ground_lean(sample:Dictionary)->void:
    var t:float=float(age)
    var lean:float=smoothstep(0.,6.,t)*(1.-smoothstep(10.,34.,t))
    var arms:float=smoothstep(3.,10.,t)*(1.-smoothstep(17.,36.,t))
    var p:Dictionary=sample.pose
    p.angles.hips-=10.*lean
    p.angles.chest-=14.*lean
    p.angles.head-=4.*lean
    p.angles.shoulder_near-=16.*arms
    p.angles.shoulder_far-=23.*arms
    p.angles.elbow_near+=18.*arms
    p.angles.elbow_far+=22.*arms
    Recovery.project_root(rig,p,IK.root_of(p),anchors)
    for side in Leg.SIDES:IK.solve_leg(rig,p,side,anchors[side],1.)
    rig.evaluate(p)
    sample.error=0.
    for side in Leg.SIDES:sample.error=maxf(sample.error,rig.point("foot_"+side).distance_to(anchors[side]))

func mix_angle(a:float,b:float,w:float)->float:
    return a+wrapf(b-a,-180.,180.)*w

func airborne()->Dictionary:
    age+=1
    flight_velocity.y+=180.*DT
    flight_position+=flight_velocity*DT
    var t:float=float(age)
    var w:float=smoothstep(0.,10.,t)
    var arm_w:float=smoothstep(1.,11.,t)
    # Reference 3: trunk leans forward into raised legs, then rotates
    # backward toward the upper-back contact in reference 5.
    var roll:float=118.*smoothstep(12.,43.,t)
    var fold:float=1.-smoothstep(24.,43.,t)
    var p:Dictionary=flight_entry.duplicate(true)
    p.root=[flight_position.x,flight_position.y]
    p.angles.hips=mix_angle(flight_entry.angles.hips,14.-roll,w)
    p.angles.chest=mix_angle(flight_entry.angles.chest,10.+25.*fold,w)
    p.angles.head=mix_angle(flight_entry.angles.head,3.+19.*fold,w)
    var chest_global:float=p.angles.hips+p.angles.chest
    for side in Leg.SIDES:
        var near:bool=side=="near"
        var upper_rest:float=rad_to_deg(Vector2(rig.joints[rig.ids["elbow_"+side]].offset).angle())-90.
        var lower_rest:float=rad_to_deg(Vector2(rig.joints[rig.ids["hand_"+side]].offset).angle())-90.
        var arm_upper:float=(-79. if near else -72.)-roll*.42
        var arm_lower:float=(-88. if near else -84.)-roll*.92
        p.angles["shoulder_"+side]=mix_angle(flight_entry.angles["shoulder_"+side],arm_upper-chest_global-upper_rest,arm_w)
        p.angles["elbow_"+side]=mix_angle(flight_entry.angles["elbow_"+side],arm_lower-arm_upper+upper_rest-lower_rest,arm_w)
        var thigh:float=(-105. if near else -93.)-roll*.33
        p.angles["thigh_"+side]=mix_angle(flight_entry.angles["thigh_"+side],thigh-p.angles.hips+Leg.rest(side),w)
        var bend:float=lerpf(Leg.bend(flight_entry,side),lerpf(near_bend(near),13. if near else 24.,fold),smoothstep(0.,9. if near else 12.,t))
        var ankle:float=lerpf(Leg.ankle(flight_entry,side),35. if near else 25.,w)
        Leg.put(p,side,bend,ankle)
    rig.evaluate(p)
    clearance=floor_y-bottom()
    support_count=0
    if flight_velocity.y>0. and clearance<=0.:
        # Remove the inward floor velocity; carry bounded horizontal inertia.
        # Reference is a pose, not a measured contact impulse.
        flight_position.y+=clearance
        p.root=[flight_position.x,flight_position.y]
        rig.evaluate(p)
        clearance=floor_y-bottom()
        state="CONTACT"
        landing_entry=p.duplicate(true)
        landing_age=0
        contact_x=flight_position.x
        contact_joint=lowest_joint()
        landing_vx=flight_velocity.x*.42
        flight_velocity=Vector2.ZERO
    flight_pose=p.duplicate(true)
    tick+=1
    return air_sample()

func near_bend(near:bool)->float:
    return 20. if near else 39.

func lowest_joint()->String:
    var name:String="hips"
    var low:float=rig.point(name).y+4.
    for id in ["chest","head","foot_near","foot_far","knee_near","knee_far","hand_near","hand_far"]:
        var radius:float=4. if id in ["chest","head"] else (1.5 if id.begins_with("foot") else (2. if id.begins_with("knee") else 2.5))
        var v:float=rig.point(id).y+radius
        if v>low:
            low=v
            name=id
    return name

func landing()->Dictionary:
    landing_age+=1
    var t:float=float(landing_age)
    var w:float=smoothstep(0.,18.,t)
    var p:Dictionary=landing_entry.duplicate(true)
    flight_position.x+=landing_vx*DT
    landing_vx*=.84
    p.root=[flight_position.x,flight_position.y]
    p.angles.hips=mix_angle(landing_entry.angles.hips,-90.,w)
    p.angles.chest=mix_angle(landing_entry.angles.chest,0.,w)
    p.angles.head=mix_angle(landing_entry.angles.head,0.,smoothstep(0.,11.,t))
    var chest_global:float=p.angles.hips+p.angles.chest
    for side in Leg.SIDES:
        var near:bool=side=="near"
        var leg_w:float=smoothstep(2. if near else 0.,24. if near else 20.,t)
        var arm_w:float=smoothstep(0.,13. if near else 17.,t)
        var upper_rest:float=rad_to_deg(Vector2(rig.joints[rig.ids["elbow_"+side]].offset).angle())-90.
        var lower_rest:float=rad_to_deg(Vector2(rig.joints[rig.ids["hand_"+side]].offset).angle())-90.
        var arm_upper:float=-65. if near else -110.
        var arm_lower:float=-77. if near else -105.
        p.angles["shoulder_"+side]=mix_angle(landing_entry.angles["shoulder_"+side],arm_upper-chest_global-upper_rest,arm_w)
        p.angles["elbow_"+side]=mix_angle(landing_entry.angles["elbow_"+side],arm_lower-arm_upper+upper_rest-lower_rest,arm_w)
        var thigh:float=-77. if near else -105.
        p.angles["thigh_"+side]=mix_angle(landing_entry.angles["thigh_"+side],thigh-p.angles.hips+Leg.rest(side),leg_w)
        Leg.put(p,side,lerpf(Leg.bend(landing_entry,side),4. if near else 6.,leg_w),lerpf(Leg.ankle(landing_entry,side),22. if near else 28.,leg_w))
    rig.evaluate(p)
    # Unilateral floor envelope projection: no suspension at first contact.
    flight_position.y+=floor_y-bottom()
    p.root=[flight_position.x,flight_position.y]
    rig.evaluate(p)
    clearance=floor_y-bottom()
    flight_pose=p.duplicate(true)
    state="FALL" if landing_age<25 else "DOWN"
    if state=="DOWN":landing_vx=0.
    tick+=1
    return air_sample()

func air_sample()->Dictionary:
    rig.evaluate(flight_pose)
    return {"pose":flight_pose.duplicate(true),"error":0.,"phase":state,"moving":"","swing":false,"anchors":anchors.duplicate(true),"accepted":seen.size(),"offset":[],"energy_proxy":[],"support_count":support_count,"clearance":clearance,"steps":total_steps,"slip":slip,"contact_joint":contact_joint,"slide":flight_position.x-contact_x}

func step()->Dictionary:
    if state=="CONTACT" or state=="FALL":return landing()
    if state=="DOWN":
        tick+=1
        return air_sample()
    if state=="AIR":return airborne()
    if state=="STEP":ground_step()
    var sample:Dictionary=super.step()
    if state=="LAUNCH":
        # Short local contact accent, then carry the actual pose into flight.
        age+=1
        if age>=3:
            flight_entry=sample.pose.duplicate(true)
            flight_position=IK.root_of(flight_entry)
            flight_velocity=Vector2(-70.,-58.)
            state="AIR"
            age=0
    elif state=="STEP":
        ground_lean(sample)
        age+=1
        if age>40:
            state="GUARD"
            support_count=2
    elif state=="LOCAL":
        age+=1
        if age>=30:state="GUARD"
    clearance=floor_y-bottom()
    sample["phase"]=state if state!="AIR" else "LAUNCH"
    sample["support_count"]=support_count
    sample["clearance"]=clearance
    sample["steps"]=total_steps
    sample["slip"]=slip
    sample["contact_joint"]=contact_joint
    sample["slide"]=0.
    sample["swing"]=support_count==1
    sample["moving"]=moving
    return sample
