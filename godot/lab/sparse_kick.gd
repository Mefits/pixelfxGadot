extends RefCounted
## v17 explosive sparse-key kick. MotionEntry is the exact v15 module.
## The three artistic targets are shared between both anatomical legs.
const Tuning=preload("res://lab/attack_tuning.gd")
const Entry=preload("res://lab/motion_entry.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Keys=preload("res://lab/sparse_kick_poses.gd")
const CHAMBER:int=9
const HIT:int=12
const RETRACT:int=22
const END:int=32
const BRAKE:float=720.
# Defaults reproduce K exactly. A second authored kick can select its own
# timings, key sampler and strike surface without duplicating the receiver.
var chamber_tick:int=CHAMBER
var hit_tick:int=HIT
var retract_tick:int=RETRACT
var end_tick:int=END

var tuning:Dictionary=Tuning.defaults(false)
var pending_tuning:Dictionary={}
var trace:PackedVector2Array=PackedVector2Array()
var trace_hit_index:int=-1
var trace_anchor:=Vector2.ZERO
# One completed take per attack, immutable while the new take is recorded.
var previous_trace:PackedVector2Array=PackedVector2Array()
var previous_trace_anchor:=Vector2.ZERO
var previous_trace_hit_index:int=-1
var peak_speed:float=0.
var peak_reach:float=0.
var current_speed:float=0.
var current_reach:float=0.
var impact_reach:float=0.

func is_roundhouse()->bool:return false

func configure(settings:Dictionary)->void:
    # Pending controls may change during an attack, but the running snapshot may not.
    pending_tuning=Tuning.normalize(settings,is_roundhouse())

func apply_tuning()->void:
    tuning=Tuning.normalize(pending_tuning,is_roundhouse())
    chamber_tick=int(tuning.prep_ticks)
    hit_tick=chamber_tick+int(tuning.strike_ticks)
    retract_tick=hit_tick+int(tuning.return_ticks)
    end_tick=retract_tick+int(tuning.recovery_ticks)

func authored_tick(tick:int)->float:
    return Tuning.source_tick(tick,tuning,is_roundhouse())

func sample_key(tick:int)->Dictionary:
    return Tuning.shape_key(Keys.sample(authored_tick(tick),float(tuning.acceleration_scale)),tuning)

func remember_completed_trace()->void:
    if active or trace.size()!=end_tick+1 or trace_hit_index<0:return
    previous_trace=trace.duplicate()
    previous_trace_anchor=trace_anchor
    previous_trace_hit_index=trace_hit_index

func inherit_trace_history(old)->void:
    # R may interrupt a take. Retain only the latest completed take.
    old.remember_completed_trace()
    previous_trace=old.previous_trace.duplicate()
    previous_trace_anchor=old.previous_trace_anchor
    previous_trace_hit_index=old.previous_trace_hit_index

func trace_start(w)->void:
    trace.clear()
    trace.append(strike_tip(w))
    trace_anchor=anchor
    trace_hit_index=-1
    peak_speed=0.
    peak_reach=0.
    impact_reach=0.
    current_speed=0.
    current_reach=trace[0].x-trace_anchor.x

func trace_sample(w)->void:
    var tip:Vector2=strike_tip(w)
    current_speed=tip.distance_to(trace[trace.size()-1])*60.
    current_reach=tip.x-trace_anchor.x
    trace.append(tip)
    # Peak speed: only the strike interval. Reach: until the end of the authored return.
    if age>chamber_tick and age<=hit_tick:peak_speed=maxf(peak_speed,current_speed)
    if age<=retract_tick:peak_reach=maxf(peak_reach,current_reach)
    if age==hit_tick:
        trace_hit_index=trace.size()-1
        impact_reach=current_reach

func contact_start()->int:return maxi(1,hit_tick-1)
func contact_end()->int:return mini(end_tick,hit_tick+1)

func strike_tip(w)->Vector2:
    return heel_tip(w)

var active:bool=false
var age:int=0
var striking:int=0
var support_leg:int=1
var plant_tick:int=0
var anchor:=Vector2.ZERO
var entry
var velocity:float=0.
var landing_pose:Dictionary={}
var landing_toes:Array=[]
var landing_shift:float=0.
var retract_pose:Dictionary={}
var retract_toes:Array=[]
var previous_tip:=Vector2.ZERO
var fired:bool=false

static func choose_support(w,e)->int:
    # An existing contact takes precedence. With two contacts use the load
    # proxy; on a tie, kick with the leading foot. During running flight
    # use the next receiving side, otherwise select the nearer-to-floor toe.
    if e.contacts[0]!=e.contacts[1]:return 0 if e.contacts[0] else 1
    if e.contacts[0]:
        var difference:float=float(w.support_load[0])-float(w.support_load[1])
        if absf(difference)>.08:return 0 if difference>0. else 1
        return 1-w.guard_lead
    if w.sprint_active and w.run_gait!=null:return 1-int(w.run_gait.side)
    var delta:float=Vector2(e.toes[0]).y-Vector2(e.toes[1]).y
    if absf(delta)>.15:return 0 if delta>0. else 1
    return 1-w.guard_lead

func start(w,right_limit:float)->bool:
    if active:return false
    remember_completed_trace()
    apply_tuning()
    entry=Entry.new(w)
    support_leg=choose_support(w,entry)
    if int(tuning.leg)>=0:support_leg=1-int(tuning.leg)
    striking=1-support_leg
    velocity=entry.velocity
    plant_tick=0 if entry.contacts[support_leg] else mini(4,chamber_tick)
    anchor=Vector2(entry.anchors[support_leg])
    anchor.y=0.
    if plant_tick>0:
        var forecast:float=w.x
        var v:float=velocity
        for i in plant_tick:
            v=move_toward(v,0.,BRAKE/60.)
            forecast=clampf(forecast+v/60.,-w.travel_limit,right_limit)
        anchor.x=forecast+Vector2(entry.toe_at(support_leg,plant_tick,chamber_tick)).x
    w.suspend_motion()
    w.direction=0
    w.idle_active=false
    w.idle_ticks=0
    age=0
    fired=false
    active=true
    previous_tip=strike_tip(w)
    trace_start(w)
    return true

# 069 heel/sole proxy in ankle-local coordinates. Keep the locomotion toe
# anchor unchanged; only the K attack queries this strike point.
func heel_tip(w)->Vector2:
    var s:String=side(striking)
    var pitch:float=deg_to_rad(float(w.pose.angles["foot_pitch_"+s]))
    return Vector2(w.rig.point("foot_"+s))+Vector2(-1.65,.35).rotated(pitch)+Vector2.RIGHT*w.x

func side(i:int)->String:
    return Motion.SIDES[i]

func phase_name()->String:
    if age<chamber_tick:return "Подъём колена"
    if age<=hit_tick:return "Выброс"
    if age<=retract_tick:return "Возврат"
    return "Постановка ноги"

func target_pose(w,k:Dictionary,plant:Vector2)->Dictionary:
    var p:Dictionary=entry.pose.duplicate(true)
    p.angles.hips=k.lean
    p.angles.chest=k.chest
    p.angles.head=k.head
    # The projection is 0..90: 45 is side-on, 90-turn swaps the
    # projected anatomical sides without changing the attack direction.
    p.angles.pelvis_turn=float(k.pelvis_turn) if striking==0 else 90.-float(k.pelvis_turn)
    p.angles.shoulder_turn=float(k.shoulder_turn) if striking==0 else 90.-float(k.shoulder_turn)
    p.angles["shoulder_"+side(striking)]=k.strike_shoulder
    p.angles["elbow_"+side(striking)]=k.strike_elbow
    p.angles["shoulder_"+side(support_leg)]=k.support_shoulder
    p.angles["elbow_"+side(support_leg)]=k.support_elbow
    p.angles["foot_pitch_"+side(support_leg)]=k.support_pitch
    p.angles["foot_pitch_"+side(striking)]=k.pitch
    # Author the pelvis relative to the real support ankle, with a small
    # forward weight shift and near-extended supporting knee at impact.
    # A rising heel pivots about the pinned toe, not the arena root.
    w.rig.evaluate(p)
    var reach:float=IK.reach(w.rig,side(support_leg))
    var dx:float=reach*float(k.support_hip_x)
    var d:float=reach*float(k.support_length)
    var ankle:Vector2=plant-IK.toe_vector(p,side(support_leg))
    var hip_goal:Vector2=ankle+Vector2(dx,-sqrt(maxf(.01,d*d-dx*dx)))
    var shift:Vector2=hip_goal-Vector2(w.rig.point("thigh_"+side(support_leg)))
    p.root[0]+=shift.x
    p.root[1]+=shift.y
    return p

func constrain_leg(w,p:Dictionary,i:int,toe:Vector2)->void:
    var s:String=side(i)
    # Pitch clamping changes the toe offset. Re-solve against that updated
    # offset before final quantization, rather than silently losing contact.
    for attempt in 3:
        var pitch_before:float=p.angles["foot_pitch_"+s]
        IK.solve_leg(w.rig,p,s,toe-IK.toe_vector(p,s),1.)
        if not Leg.valid(p,s):Leg.put(p,s,Leg.bend(p,s),Leg.ankle(p,s))
        w.rig.evaluate(p)
        if absf(pitch_before-float(p.angles["foot_pitch_"+s]))<.001:break

func solve_free(w,p:Dictionary,toe:Vector2)->void:
    toe.y=minf(0.,toe.y)
    constrain_leg(w,p,striking,toe)
    # When an ankle or knee reaches its limit, keep the unweighted toe
    # above the floor without translating the already planted support leg.
    for attempt in 3:
        var actual:Vector2=Motion.toe(w.rig,p,side(striking))
        if actual.y<=.002:break
        toe.y-=actual.y+.01
        constrain_leg(w,p,striking,toe)

func write_pose(w,p:Dictionary,planted:bool,free_planted:bool=false)->void:
    Grid.pose(p)
    w.rig.evaluate(p)
    var toes:Array=Motion.toes(w.rig,p)
    w.previous_pose=w.pose
    w.pose=p
    w.paths=[]
    w.support_load=[0.,0.]
    for i in 2:
        var contact:bool=planted if i==support_leg else free_planted
        w.paths.append({"toe":toes[i],"pitch":p.angles["foot_pitch_"+side(i)],"stance":contact})
    if planted:w.support_load[support_leg]=.5 if free_planted else 1.
    if free_planted:w.support_load[striking]=.5

func prepare_landing(w)->void:
    # Preserve the real support foot; set the attacking foot in front.
    w.guard_lead=striking
    var guard:Dictionary=w.guard_intent(w.programs.walk_idle,0.)
    landing_pose=Motion.resolve(w.rig,w.support,guard)
    landing_toes=Motion.toes(w.rig,landing_pose)
    landing_shift=anchor.x-w.x-Vector2(landing_toes[support_leg]).x
    var offset:=Vector2(landing_shift,-Vector2(landing_toes[support_leg]).y)
    landing_pose.root[0]+=offset.x
    landing_pose.root[1]+=offset.y
    landing_toes=Motion.toes(w.rig,landing_pose)
    w.rig.evaluate(w.pose)

func step(w,right_limit:float)->void:
    if not active:return
    age+=1
    # Incoming motor momentum decays rather than being discarded or
    # accidentally inherited by the next command. The support foot stays put.
    velocity=move_toward(velocity,0.,BRAKE/60.)
    var next:float=clampf(w.x+velocity/60.,-w.travel_limit,right_limit)
    w.ground_speed=(next-w.x)*60.
    if absf(w.ground_speed-velocity)>.001:velocity=0.
    w.x=next
    var plant:Vector2=anchor-Vector2.RIGHT*w.x
    if age>retract_tick:
        # Last artistic key -> generated landing. Only one support anchor;
        # the striking leg is free until the final frame.
        var u:float=smoothstep(float(retract_tick),float(end_tick),float(age))
        var p:Dictionary=Clips.blend_pose(retract_pose,landing_pose,u)
        var toe:Vector2=Vector2(retract_toes[striking]).lerp(Vector2(landing_toes[striking]),u)
        toe.y-=1.0*sin(PI*u)
        if age>=end_tick:
            p=landing_pose.duplicate(true)
            # This pose was solved against the final guard before translating.
            write_pose(w,p,true,true)
            var shift:float=clampf(landing_shift,-w.travel_limit-w.x,right_limit-w.x)
            w.rebase_landing(shift)
            w.previous_pose.root[0]-=shift
            w.ground_speed=0.
            w.capture_transition()
            w.direction=0
            active=false
            return
        constrain_leg(w,p,support_leg,plant)
        var residual:Vector2=plant-Motion.toe(w.rig,p,side(support_leg))
        p.root[0]+=residual.x
        p.root[1]+=residual.y
        solve_free(w,p,toe)
        write_pose(w,p,true)
        return
    var k:Dictionary=sample_key(age)
    var target:Dictionary=target_pose(w,k,plant)
    var mix:float=smoothstep(0.,float(chamber_tick),float(age))
    var p:Dictionary=Clips.blend_pose(entry.continued(age,chamber_tick),target,mix)
    # If both feet were in flight, settle only the receiving leg. Keep the
    # previous toe trajectory until the predicted touchdown, then pin it.
    var planted:bool=age>=plant_tick
    var approach:float=1. if plant_tick==0 else smoothstep(0.,float(plant_tick),float(age))
    var support_toe:Vector2=Vector2(entry.toe_at(support_leg,age,chamber_tick)).lerp(plant,approach)
    support_toe.y=minf(0.,support_toe.y)
    constrain_leg(w,p,support_leg,support_toe)
    if planted:
        var residual:Vector2=plant-Motion.toe(w.rig,p,side(support_leg))
        p.root[0]+=residual.x
        p.root[1]+=residual.y
        w.rig.evaluate(p)
    # A hip-relative goal is independent of character scale and near/far
    # anatomy. The positive knee-bend branch is shared by both legs.
    var reach:float=IK.reach(w.rig,side(striking))
    var goal:Vector2=Vector2(w.rig.point("thigh_"+side(striking)))+Vector2(k.ankle)*reach+IK.toe_vector(p,side(striking))
    var toe:Vector2=Vector2(entry.toe_at(striking,age,chamber_tick)).lerp(goal,mix)
    toe.y=minf(0.,toe.y)
    solve_free(w,p,toe)
    write_pose(w,p,planted)
    if age==retract_tick:
        retract_pose=w.pose.duplicate(true)
        retract_toes=Motion.toes(w.rig,w.pose)
        prepare_landing(w)
