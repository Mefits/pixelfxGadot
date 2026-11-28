extends RefCounted
## Isolated single-attack preview. No new gameplay hit or cancel policy.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Idle=preload("res://lab/spatial_lab/spatial_idle_013.gd")
const Attack=preload("res://lab/spatial_lab/spatial_kick_profile_014.gd")
const ENTRY:int=6
const RECOVERY:int=12
const PRE:int=12
const TOTAL:int=108
var idle=Idle.new()
var attack=Attack.new()
var rig=FK.new()
var desired=FK.new()
var pose:Dictionary={}
var mode:int=1
var phase:int=0
var entry
var recovery
var attack_offset:=Vector3.ZERO
var return_offset:=Vector3.ZERO
var return_winding:int=0
var initial_anchor:=Vector3.ZERO
var final_anchor:=Vector3.ZERO
var current:Dictionary={}
var previous:Dictionary={}
var last_tick:int=-1
var attack_end:int=0
var metrics:Dictionary={}

func setup(art:Dictionary,profile:int,idle_phase:int)->void:
    pose=art.duplicate(true)
    mode=profile
    phase=idle_phase
    idle.mode=3
    idle.setup(pose)
    attack.mode=mode
    attack.setup(pose)
    attack_end=Attack.DURATIONS[mode]
    entry=null
    recovery=null
    last_tick=-1
    current={}
    previous={}
    metrics={"max_anchor_error":0.,"max_root_correction":0.,"max_free_toe_y":-100.,"contact_switches":[]}
    
func idle_sample(t:int,offset:Vector3=Vector3.ZERO,winding:int=0)->Dictionary:
    assert(idle.idle(t).accepted)
    Entry.write_exact(desired,Entry.sample(idle.rig,pose))
    desired.yaw_units+=winding
    for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+offset
    Entry.update_xy(desired)
    return Entry.sample(desired,pose)

func shifted_attack_sample()->Dictionary:
    Entry.write_exact(desired,Entry.sample(attack.rig,pose))
    for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+attack_offset
    Entry.update_xy(desired)
    return Entry.sample(desired,pose)

# Keep the near toe anchor during entry/recovery; let the foot orientation
# follow the desired pose. Seed the knee plane from the desired sample so
# this adapter introduces no hidden temporal state or pole recapture drift.
func anchor_near(anchor:Vector3)->Dictionary:
    var solver=Support.new()
    solver.capture(desired,pose,"near",Support.FIXED)
    solver.contacts.near.anchor=anchor
    var q:Dictionary=solver.resolve_evaluated(rig,desired,8.)
    if q.accepted:
        metrics.max_root_correction=maxf(metrics.max_root_correction,Vector3(q.root_shift).length())
    return q

func publish(tick:int,anchor:Vector3,side:String)->Dictionary:
    var e:float=Support.toe(rig,pose,side).distance_to(anchor)
    metrics.max_anchor_error=maxf(metrics.max_anchor_error,e)
    var free:String="far" if side=="near" else "near"
    metrics.max_free_toe_y=maxf(metrics.max_free_toe_y,Support.toe(rig,pose,free).y)
    previous=current
    current=Entry.sample(rig,pose)
    last_tick=tick
    return {"accepted":e<Support.TOL,"anchor_error":e,"side":side}

func step(tick:int)->Dictionary:
    assert(tick==last_tick+1 and tick<TOTAL)
    var local:int=tick-PRE
    if local<0:
        var s:Dictionary=idle_sample(phase+local)
        Entry.write_exact(rig,s)
        return publish(tick,s.toes.near,"near")
    if local<=attack_end:
        var q:Dictionary=attack.evaluate_style(local)
        if not q.accepted:return q
        if local==0:
            var now:Dictionary=idle_sample(phase)
            var prior:Dictionary=idle_sample(phase-1)
            entry=Entry.new(now,prior)
            initial_anchor=now.toes.near
            attack_offset=initial_anchor-Support.toe(attack.rig,pose,"near")
        var target:Dictionary=shifted_attack_sample()
        if local==0:
            Entry.write_exact(rig,entry.current)
        elif local<ENTRY:
            entry.blend(desired,target,local,ENTRY)
            q=anchor_near(initial_anchor)
            if not q.accepted:return q
        else:
            Entry.write_exact(rig,target)
        var side:String=attack.active_side
        var anchor:Vector3=Vector3(attack.support.contacts[side].anchor)+attack_offset
        if local==0 or (metrics.contact_switches[-1][1]!=side):
            metrics.contact_switches.append([local,side])
        if local==attack_end:
            final_anchor=Support.toe(rig,pose,"near")
        return publish(tick,anchor,side)
    var age:int=local-attack_end
    if age==1:
        recovery=Entry.new(current,previous)
        var dest:Dictionary=idle_sample(phase+local)
        return_offset=final_anchor-Vector3(dest.toes.near)
        return_winding=roundi(float(int(current.yaw)-int(dest.yaw))/FK.TURN)*FK.TURN
    var target:Dictionary=idle_sample(phase+local,return_offset,return_winding)
    if age<RECOVERY:
        recovery.blend(desired,target,age,RECOVERY)
        var q:Dictionary=anchor_near(final_anchor)
        if not q.accepted:return q
    else:
        Entry.write_exact(rig,target)
    return publish(tick,final_anchor,"near")
