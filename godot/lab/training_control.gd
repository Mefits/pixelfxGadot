extends RefCounted
const Round=preload("res://lab/roundhouse_kick.gd")
const Kick=preload("res://lab/sparse_kick.gd")
const Jump=preload("res://lab/jump_control.gd")
const Recovery=preload("res://lab/attack_recovery.gd")
const Adapt=preload("res://lab/attack_adaptation.gd")
const Punch=preload("res://lab/training_punch.gd")
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const BAG_X:float=34.
const BAG_RADIUS:float=6.
const BAG_TOP:float=-45.
const BAG_BOTTOM:float=-13.
const MAX_CHAIN:int=3
var walker
var jump=Jump.new()
var kick=Kick.new()
var round_kick=Round.new()
var round_queued:bool=false
var kick_queued:bool=false
var docs:Dictionary={}
var active:int=0
var age:int=0
var queued:int=0
var ticks:int=0
var chain:int=0
var last_chain:int=0
var starts:Array=[]
var strikes:int=0
var hits:int=0
var misses:int=0
var hit_flash:int=0
var bag_sway:float=0.
var result:String="—"
var feet:Array=[]
var entry:Dictionary={}
var binding:Dictionary={}
var strike_anchor:String=""
var preparation_age:int=0
var landing:Dictionary={}
var release_tick:int=0
var previous_tip:=Vector2.ZERO
var fired:bool=false

func _init(overrides:Dictionary={},profile_override:Dictionary={}):
    walker=Walk.new({},profile_override)
    var loadout:Dictionary=Punch.loadout()
    for i in 3:docs[i+1]=overrides.get(i+1,loadout[i+1])
    # Idle starts at once, not after a hidden warm-up.
    walker.step(0)

func press(key:int=1)->bool:
    if key!=1 or jump.state!=0 or kick.active or round_kick.active:return false
    if active==0:
        queued=0
        begin(1,1)
        return true
    # Each fresh press buys exactly one future strike. Fast 1,1,1
    # is valid; no repeated/held input or extra stage can overflow.
    if active+queued<MAX_CHAIN:
        queued+=1
        return true
    return false

func press_jump(move:int=0)->bool:
    if active!=0 or kick.active or round_kick.active:return false
    if jump.state==2:return jump.try_second(walker,move)
    return jump.start(walker,move)

# K is independent of the accepted three-hit combo. One buffered K can
# follow the currently committed combo; the existing 1 input is unchanged.
func press_kick()->bool:
    if jump.state!=0 or kick.active or round_kick.active or kick_queued or round_queued:return false
    if active!=0:
        kick_queued=true
        return true
    return begin_kick()

# L has its own receiver, target surface and single shared combo buffer.
func press_round_kick()->bool:
    if jump.state!=0 or kick.active or round_kick.active or kick_queued or round_queued:return false
    if active!=0:
        round_queued=true
        return true
    return begin_round_kick()

func begin_round_kick()->bool:
    round_queued=false
    if not round_kick.start(walker,ground_right_limit()):return false
    result="Круговой удар L"
    return true

func round_kick_step()->void:
    round_kick.step(walker,ground_right_limit())
    round_kick.trace_sample(walker)
    var current:Vector2=round_kick.strike_tip(walker)
    if not round_kick.fired and round_kick.age>=round_kick.contact_start():
        if contact(round_kick.previous_tip,current):
            round_kick.fired=true
            strikes+=1
            hits+=1
            hit_flash=7
            bag_sway=4.5
            result="Попадание L"
        elif round_kick.age>=round_kick.contact_end():
            round_kick.fired=true
            strikes+=1
            misses+=1
            result="Промах L"
    round_kick.previous_tip=current

func ground_right_limit()->float:
    if walker.x<=BAG_X:return minf(walker.travel_limit,maxf(walker.x,BAG_X-BAG_RADIUS-9.))
    return walker.travel_limit

func begin_kick()->bool:
    kick_queued=false
    if not kick.start(walker,ground_right_limit()):return false
    result="Удар K"
    return true

func kick_step()->void:
    kick.step(walker,ground_right_limit())
    kick.trace_sample(walker)
    var current:Vector2=kick.heel_tip(walker)
    if not kick.fired and kick.age>=kick.contact_start():
        if contact(kick.previous_tip,current):
            kick.fired=true
            strikes+=1
            hits+=1
            hit_flash=7
            bag_sway=4.5
            result="Попадание K"
        elif kick.age>=kick.contact_end():
            kick.fired=true
            strikes+=1
            misses+=1
            result="Промах K"
    kick.previous_tip=current

func begin(key:int,count:int)->void:
    active=key
    age=0
    preparation_age=0
    fired=false
    chain=count
    starts.append(key)
    entry=walker.pose.duplicate(true)
    feet=Motion.toes(walker.rig,walker.pose)
    walker.suspend_motion()
    walker.direction=0
    walker.idle_active=false
    walker.idle_ticks=0
    binding=Adapt.bind(docs[key],walker.rig,entry,walker.guard_lead)
    strike_anchor=binding.anchor
    landing=Recovery.plan(docs[key],walker,binding)
    release_tick=roundi(float(docs[key].duration)*60.) if landing.is_empty() else int(landing.end)
    walker.rig.evaluate(walker.pose)
    walker.guard_lead=binding.lead
    previous_tip=tip(strike_anchor)
    result="Удар "+str(key)

func tip(anchor:String)->Vector2:
    if anchor.begins_with("foot_"):
        return Motion.toe(walker.rig,walker.pose,anchor.trim_prefix("foot_"))+Vector2.RIGHT*walker.x
    var wrist:Vector2=walker.rig.point(anchor)
    var elbow:Vector2=walker.rig.point(anchor.replace("hand_","elbow_"))
    return wrist+(wrist-elbow).normalized()*2.55+Vector2.RIGHT*walker.x

func contact(a:Vector2,b:Vector2)->bool:
    # Fixed training target. Visual sway never changes its collision shape.
    var closest:Vector2=Geometry2D.get_closest_point_to_segment(Vector2(BAG_X,clampf(b.y,BAG_TOP,BAG_BOTTOM)),a,b)
    # Segment vs vertical capsule axis (distance minimized along the sweep).
    for i in 9:
        var p:Vector2=a.lerp(b,float(i)/8.)
        if p.distance_to(Vector2(BAG_X,clampf(p.y,BAG_TOP,BAG_BOTTOM)))<=BAG_RADIUS+1.5:return true
    return closest.distance_to(Vector2(BAG_X,clampf(closest.y,BAG_TOP,BAG_BOTTOM)))<=BAG_RADIUS+1.5

func step(move:int,sprint:bool=false)->void:
    ticks+=1
    hit_flash=maxi(0,hit_flash-1)
    bag_sway=move_toward(bag_sway,0.,.32)
    if jump.state!=0:
        jump.step(walker,move)
        return
    if kick.active:
        kick_step()
        return
    if round_kick.active:
        round_kick_step()
        return
    if active==0:
        var right_limit:float=INF
        if walker.x<=BAG_X:
            # The bag stops ground movement from the left, including a
            # sprint's braking momentum. Already-overlapping poses may retreat.
            right_limit=maxf(walker.x,BAG_X-BAG_RADIUS-9.)
        walker.step(move,sprint,right_limit)
        return
    var d:Dictionary=docs[active]
    if preparation_age<int(binding.prepare_ticks):
        preparation_age+=1
        var preparation:Dictionary=Adapt.prepare_pose(walker.rig,binding,preparation_age)
        walker.previous_pose=walker.pose
        Punch.apply(walker,Punch.pose_intent(preparation,walker.rig))
        previous_tip=tip(strike_anchor)
        if preparation_age==int(binding.prepare_ticks):walker.guard_lead=binding.target_lead
        return
    var duration:int=roundi(float(d.duration)*60.)
    age+=1
    var time:float=minf(float(age)/60.,float(d.duration))
    var value:Dictionary=Punch.intent(d,time,walker.rig,feet,entry,binding)
    if not landing.is_empty() and age>int(landing.start):
        value=Punch.pose_intent(Recovery.pose_at(value.pose,walker.rig,landing,age),walker.rig)
    walker.previous_pose=walker.pose
    Punch.apply(walker,value)
    var current:Vector2=tip(strike_anchor)
    var marker:int=ceili(float(binding.events[0].t)*60.)
    var window_start:int=maxi(1,marker-3)
    var window_end:int=mini(duration,marker+2)
    if not fired and age>=window_start:
        if contact(previous_tip,current):
            fired=true
            strikes+=1
            hits+=1
            hit_flash=7
            bag_sway=4.5
            result="Попадание "+str(active)
        elif age>=window_end:
            fired=true
            strikes+=1
            misses+=1
            result="Промах "+str(active)
    previous_tip=current
    # Shared boundary frame: next slice starts at the same source pose.
    if queued>0 and active<MAX_CHAIN and age>=release_tick and fired:
        queued-=1
        if not landing.is_empty():walker.rebase_landing(float(landing.advance))
        begin(active+1,chain+1)
        return
    if age>=release_tick:
        last_chain=chain
        active=0
        queued=0
        chain=0
        if not landing.is_empty():
            walker.rebase_landing(float(landing.advance))
            walker.previous_pose.root[0]-=float(landing.advance)
        walker.capture_transition()
        walker.direction=0
        # Movement is available on the next simulation tick; no locked tail.
        # A held direction enters the regular continuous walk transition.
        if kick_queued:begin_kick()
        elif round_queued:begin_round_kick()
