extends RefCounted
## Role binding is per action, never per frame. The authored document is immutable.
## near/far remain physical render/rig identities; only motion channels are mapped.
const Motion=preload("res://lab/walk_motion.gd")
const Clips=preload("res://addons/creature/clips.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const ROLES=["auto","leading","trailing","near","far","authored"]
const DEFAULT_ROLES={"combo_original_1":"leading","combo_original_2":"trailing","combo_original_3":"trailing"}
const SIDES=["near","far"]
const DEADBAND:float=.6
const PREP_TICKS:int=16

static func role(doc:Dictionary)->String:
    return str(doc.get("limb_role",DEFAULT_ROLES.get(doc.get("id",""),"auto")))

static func side_of(anchor:String)->int:
    return 1 if anchor.ends_with("_far") else 0

static func lead_of(toes:Array,fallback:int)->int:
    var dx:float=Vector2(toes[0]).x-Vector2(toes[1]).x
    return fallback if absf(dx)<=DEADBAND else (0 if dx>0. else 1)

static func map_anchor(anchor:String,swapped:bool)->String:
    if not swapped:return anchor
    if anchor.ends_with("_near"):return anchor.trim_suffix("_near")+"_far"
    if anchor.ends_with("_far"):return anchor.trim_suffix("_far")+"_near"
    return anchor

static func offset_angle(rig,joint:String)->float:
    return Vector2(rig.joints[rig.ids[joint]].offset).angle()

# A bare channel swap is wrong: the two sides have different rest angles.
# Preserve projected limb segment directions using the rest-angle delta.
static func mapped_pose(p:Dictionary,rig,swapped:bool)->Dictionary:
    return mapped_channels(p,rig,swapped,swapped)

static func mapped_channels(p:Dictionary,rig,arms_swapped:bool,legs_swapped:bool)->Dictionary:
    var q:Dictionary=p.duplicate(true)
    for i in 2:
        var dst:String=SIDES[i]
        var src:String=SIDES[1-i]
        for chain in [["shoulder_","elbow_","hand_"],["thigh_","knee_","foot_"]]:
            if not (arms_swapped if chain[0]=="shoulder_" else legs_swapped):continue
            var upper:float=offset_angle(rig,chain[1]+src)-offset_angle(rig,chain[1]+dst)
            var lower:float=offset_angle(rig,chain[2]+src)-offset_angle(rig,chain[2]+dst)
            q.angles[chain[0]+dst]=float(p.angles[chain[0]+src])+rad_to_deg(upper)
            q.angles[chain[1]+dst]=float(p.angles[chain[1]+src])+rad_to_deg(lower-upper)
        if legs_swapped:q.angles["foot_pitch_"+dst]=p.angles["foot_pitch_"+src]
    if arms_swapped:q.angles.shoulder_turn=90.-clampf(float(p.angles.shoulder_turn),0.,90.)
    if legs_swapped:q.angles.pelvis_turn=90.-clampf(float(p.angles.pelvis_turn),0.,90.)
    return q

# The primary strike marker defines the authored limb. Resolve once using
# actual feet at the boundary, then latch until the action ends.
static func bind(doc:Dictionary,rig,entry:Dictionary,previous_lead:int)->Dictionary:
    var first:Dictionary=Motion.sample(doc,0.)
    var source_toes:Array=Motion.toes(rig,first)
    var source_lead:int=lead_of(source_toes,0)
    var entry_toes:Array=Motion.toes(rig,entry)
    var lead:int=lead_of(entry_toes,previous_lead)
    var marker:Dictionary=doc.events[0]
    var anchor:String=str(marker.anchor)
    var authored:int=side_of(anchor)
    var chosen:int=authored
    match role(doc):
        "leading":chosen=lead
        "trailing":chosen=1-lead
        "near":chosen=0
        "far":chosen=1
        "auto":chosen=authored if source_lead==lead else 1-authored
    var swapped:bool=chosen!=authored
    # A hand's anatomical role must not force the legs into a different guard.
    var hand_attack:bool=anchor.begins_with("hand_")
    var legs_swapped:bool=(source_lead!=lead) if hand_attack and role(doc)!="authored" else swapped
    var start:Dictionary=mapped_channels(first,rig,swapped,legs_swapped)
    var target_toes:Array=Motion.toes(rig,start)
    # Detect stationary authored support by geometry, not by clip ID. Explicit
    # authored mode remains a raw reference; airborne/walking entries use the
    # regular transition rather than locking a foot in mid-air.
    var planted:bool=hand_attack and role(doc)!="authored" and absf(Vector2(entry_toes[0]).x-Vector2(entry_toes[1]).x)>DEADBAND and grounded(entry_toes) and stationary_support(doc,rig,source_toes)
    var root_shift:Vector2=Vector2.ZERO
    if planted:
        root_shift=(Vector2(entry_toes[0])+Vector2(entry_toes[1])-Vector2(target_toes[0])-Vector2(target_toes[1]))*.5
        root_shift.y=0.
        start=plant_pose(rig,start,entry_toes,root_shift)
        target_toes=Motion.toes(rig,start)
    var events:Array=[]
    for event in doc.events:
        var mapped:Dictionary=event.duplicate(true)
        mapped.anchor=map_anchor(str(event.anchor),swapped)
        events.append(mapped)
    # No unnecessary entry blend at a continuous combo boundary.
    var continuous:bool=entry==start
    var target_lead:int=lead_of(target_toes,lead)
    var preparation:int=PREP_TICKS if target_lead!=lead or (not continuous and float(marker.t)<.05) else 0
    var blend_time:float=minf(.10,float(marker.t)*.5)
    if continuous or preparation>0:blend_time=0.
    rig.evaluate(entry)
    return {"swapped":swapped,"legs_swapped":legs_swapped,"planted":planted,"root_shift":root_shift,"lead":lead,"role":role(doc),"anchor":map_anchor(anchor,swapped),"events":events,"entry":entry.duplicate(true),"entry_toes":entry_toes,"start_toes":target_toes,"blend_time":blend_time,"start":start,"prepare_ticks":preparation,"target_lead":target_lead}

static func sample(doc:Dictionary,time:float,rig,binding:Dictionary)->Dictionary:
    var authored:Dictionary=Motion.sample(doc,clampf(time/float(doc.duration),0.,1.))
    if binding.is_empty():return authored
    var p:Dictionary=mapped_channels(authored,rig,binding.swapped,binding.legs_swapped)
    var duration:float=binding.blend_time
    if time<=0.:return binding.entry.duplicate(true)
    if binding.planted:
        # Move the authored pelvis relative to the real support midpoint, not
        # the canonical clip coordinates. All original hand angles and timing
        # remain intact after the short entry blend.
        p.root[0]+=Vector2(binding.root_shift).x
        if duration>0. and time<duration:
            p=Clips.blend_pose(binding.entry,p,smoothstep(0.,duration,time))
        return plant_pose(rig,p,binding.entry_toes,Vector2.ZERO)
    if duration<=0. or time>=duration-0.000001:return p
    var w:float=smoothstep(0.,duration,time)
    var target_toes:Array=Motion.toes(rig,p)
    p=Clips.blend_pose(binding.entry,p,w)
    # Reconcile the entry with the current authored contact trajectories, not
    # with a forced canonical stance. Exact FK resumes before the strike.
    for i in 2:
        var side:String=SIDES[i]
        var target:Vector2=Vector2(binding.entry_toes[i]).lerp(target_toes[i],w)
        solve_toe(rig,p,side,target)
    return p

static func grounded(toes:Array)->bool:
    return absf(Vector2(toes[0]).y)<.35 and absf(Vector2(toes[1]).y)<.35

static func stationary_support(doc:Dictionary,rig,first_toes:Array)->bool:
    if not grounded(first_toes):return false
    for k in doc.keys:
        var p:Dictionary={"angles":k.angles,"root":k.root}
        var toes:Array=Motion.toes(rig,p)
        for i in 2:
            if Vector2(toes[i]).distance_to(first_toes[i])>.05:return false
    return true

# Project the desired root into the two leg reach disks before analytic IK.
# This preserves support even if a narrower/wider guard makes raw FK unreachable.
static func plant_pose(rig,p:Dictionary,toes:Array,shift:Vector2)->Dictionary:
    p.root[0]+=shift.x
    p.root[1]+=shift.y
    rig.evaluate(p)
    var centers:Array=[]
    for i in 2:
        var side:String=SIDES[i]
        centers.append(Vector2(toes[i])-IK.toe_vector(p,side)-rig.point("thigh_"+side))
    var correction:=Vector2.ZERO
    for iteration in 20:
        for i in 2:
            var delta:Vector2=correction-Vector2(centers[i])
            var radius:float=IK.reach(rig,SIDES[i])-.003
            if delta.length()>radius:correction=Vector2(centers[i])+delta.normalized()*radius
    p.root[0]+=correction.x
    p.root[1]+=correction.y
    for i in 2:
        # A standing human uses the forward knee bend branch on both sides.
        IK.solve_leg(rig,p,SIDES[i],Vector2(toes[i])-IK.toe_vector(p,SIDES[i]),1.)
    return p

static func solve_toe(rig,p:Dictionary,side:String,target:Vector2)->void:
    rig.evaluate(p)
    var upper:Vector2=rig.point("knee_"+side)-rig.point("thigh_"+side)
    var lower:Vector2=rig.point("foot_"+side)-rig.point("knee_"+side)
    var bend:float=1. if upper.cross(lower)>=0. else -1.
    IK.solve_leg(rig,p,side,target-IK.toe_vector(p,side),bend)

# An explicitly fixed/authored limb may require a stance change. Do not
# teleport or consume any attack frames: prepare a separate, sequential step.
static func prepare_pose(rig,binding:Dictionary,tick:int)->Dictionary:
    var u:float=clampf(float(tick)/float(binding.prepare_ticks),0.,1.)
    if u<=0.:return binding.entry.duplicate(true)
    if u>=1.:return binding.start.duplicate(true)
    var p:Dictionary=Clips.blend_pose(binding.entry,binding.start,smoothstep(0.,1.,u))
    for i in 2:
        var first:bool=i==binding.target_lead
        var k:float=clampf(u*2.-(0. if first else 1.),0.,1.)
        var old:Vector2=binding.entry_toes[i]
        var goal:Vector2=binding.start_toes[i]
        var target:Vector2=old.lerp(goal,smoothstep(0.,1.,k))
        if absf(old.x-goal.x)>.3:target.y-=1.2*pow(sin(PI*k),2.)
        var pitch:String="foot_pitch_"+SIDES[i]
        p.angles[pitch]=lerpf(float(binding.entry.angles[pitch]),float(binding.start.angles[pitch]),smoothstep(0.,1.,k))
        solve_toe(rig,p,SIDES[i],target)
    return p
