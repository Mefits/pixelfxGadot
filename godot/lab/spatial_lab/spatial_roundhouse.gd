extends RefCounted
## Experimental L only. Consumes an ISOLATED Training instance as authored
## motion/timing oracle. Do not pass a live production actor.
## No authoritative hits emitted: legacy and spatial XY results are diagnostics.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Transition=preload("res://lab/spatial_lab/spatial_transition.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Tuning=preload("res://lab/attack_tuning.gd")
const Training=preload("res://lab/training_control.gd")
var player=Transition.new()
var desired=FK.new()
var control
var frames:Array=[]
var tuning:Dictionary={}
var striking:int=0
var support_leg:int=1
var plant_tick:int=0
var chamber_tick:int=0
var hit_tick:int=0
var retract_tick:int=0
var end_tick:int=0
var contact_start:int=0
var contact_end:int=0
var start_yaw:int=0
var direction:int=1
var age:int=0
var active:bool=false
var fired:bool=false
var diagnostic:Dictionary={}
var previous_tip:=Vector3.ZERO
var origin_x:float=0.
var anchor_xyz:=Vector3.ZERO
var planted:bool=false
var pose:Dictionary={}
var pending_tuning:Dictionary={}
var max_root_orbit:float=0.

func configure(settings:Dictionary)->void:
    pending_tuning=Tuning.normalize(settings,true)

func world_pose(w)->Dictionary:
    var p:Dictionary=w.pose.duplicate(true)
    p.root[0]+=w.x
    return p

func record(f)->Dictionary:
    var w=f.walker
    return {"pose":world_pose(w),"legacy_tip":f.round_kick.strike_tip(w),"legacy_strikes":f.strikes,"legacy_hits":f.hits,"legacy_misses":f.misses,"planted":bool(w.paths[support_leg].stance)}

# Explicit new yaw channel; old pelvis_turn and shoulder_turn remain
# projection channels only. A 65-degree wind-up reverses into impact at
# aligned yaw, then continues through the remaining full turn. Both legs
# use opposite signed turns. Timing knots are mapped from authored ticks.
func yaw_at(tick:int)->int:
    var t:float=Tuning.source_tick(tick,tuning,true)
    var knots:Array=[[0.,0.],[10.,-65.],[13.,0.],[18.,115.],[26.,265.],[36.,360.]]
    var degrees:float=360.
    for i in range(knots.size()-1):
        var lo:Array=knots[i]
        var hi:Array=knots[i+1]
        if t<=float(hi[0]):
            degrees=lerpf(float(lo[1]),float(hi[1]),smoothstep(float(lo[0]),float(hi[0]),t))
            break
    return start_yaw+direction*roundi(degrees*65536./360.)

func strike_tip()->Vector3:
    var side:String=Support.SIDES[striking]
    return player.rig.point3("knee_"+side).lerp(player.rig.point3("foot_"+side),.9)

func begin(isolated,initial_yaw:int=0)->bool:
    if active:return false
    control=isolated
    control.round_kick.configure(pending_tuning)
    if not control.press_round_kick():return false
    var actor=control.round_kick
    tuning=actor.tuning.duplicate(true)
    striking=actor.striking
    support_leg=actor.support_leg
    plant_tick=actor.plant_tick
    chamber_tick=actor.chamber_tick
    hit_tick=actor.hit_tick
    retract_tick=actor.retract_tick
    end_tick=actor.end_tick
    contact_start=actor.contact_start()
    contact_end=actor.contact_end()
    start_yaw=initial_yaw
    direction=1 if striking==0 else -1
    origin_x=control.walker.x
    frames.clear()
    frames.append(record(control))
    for i in end_tick:
        control.step(0)
        frames.append(record(control))
    pose=frames[0].pose.duplicate(true)
    desired.lift_legacy(pose,start_yaw)
    player.seed(desired,pose)
    planted=plant_tick==0
    if planted:
        player.contact(Support.SIDES[support_leg],Support.PIVOT)
        anchor_xyz=player.support.contacts[Support.SIDES[support_leg]].anchor
    player.command(maxi(1,mini(6,chamber_tick)))
    # Consume the exact boundary without advancing the original attack clock.
    var first:Dictionary=player.step(Entry.sample(desired,pose))
    if not first.accepted:return false
    age=0
    active=true
    fired=false
    diagnostic={}
    previous_tip=strike_tip()
    max_root_orbit=0.
    return true

func step()->Dictionary:
    if not active:return {"accepted":false,"reason":"inactive"}
    var next:int=age+1
    var authored:Dictionary=frames[next].pose.duplicate(true)
    var yaw:int=yaw_at(next)
    desired.lift_legacy(authored,yaw)
    var side:String=Support.SIDES[support_leg]
    var old_contacts:Dictionary=player.support.contacts.duplicate(true)
    var old_current:Dictionary=player.current.duplicate(true)
    var old_anchor:Vector3=anchor_xyz
    var new_plant:bool=not planted and next>=plant_tick
    if new_plant:
        # Capture the actual authored receiving pose at scheduled touchdown,
        # not an arbitrary airborne point from the previous tick.
        player.support.capture(desired,authored,side,Support.PIVOT)
        anchor_xyz=player.support.contacts[side].anchor
    var orbit:=Vector3.ZERO
    if planted or new_plant:
        # Rigid root orbit around the real world toe. Keep the yaw pose
        # independent of camera projection; let spatial IK correct remaining
        # differences in foot pitch and transition residuals.
        orbit=anchor_xyz-Support.toe(desired,authored,side)
        for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+orbit
        Entry.update_xy(desired)
    var target:Dictionary=Entry.sample(desired,authored)
    var result:Dictionary=player.step(target)
    if not result.accepted:
        player.support.contacts=old_contacts
        player.current=old_current
        anchor_xyz=old_anchor
        return result
    planted=planted or new_plant
    age=next
    pose=result.pose
    max_root_orbit=maxf(max_root_orbit,orbit.length())
    var tip:Vector3=strike_tip()
    # Same existing XY sweep query, no Z gate, no event dispatched to game.
    if not fired and age>=contact_start:
        var hit:bool=control.contact(Vector2(previous_tip.x,previous_tip.y),Vector2(tip.x,tip.y))
        if hit or age>=contact_end:
            fired=true
            diagnostic={"tick":age,"hit":hit,"tip":tip}
    previous_tip=tip
    if age>=end_tick:active=false
    result["tick"]=age
    result["tip"]=tip
    result["legacy_tip"]=frames[age].legacy_tip
    result["diagnostic"]=diagnostic.duplicate(true)
    result["orbit"]=orbit
    return result

# Lossless local checkpoint; precomputed source frames are intentionally
# included in this prototype. No Object, render caches or native physics.
const SNAP_FIELDS=["frames","tuning","striking","support_leg","plant_tick","chamber_tick","hit_tick","retract_tick","end_tick","contact_start","contact_end","start_yaw","direction","age","active","fired","diagnostic","previous_tip","origin_x","anchor_xyz","planted","pose","pending_tuning","max_root_orbit"]
func checkpoint()->Dictionary:
    var s:Dictionary={}
    for id in SNAP_FIELDS:s[id]=get(id)
    s["player"]=player.checkpoint()
    return s.duplicate(true)

func load_checkpoint(s:Dictionary)->void:
    var copy:Dictionary=s.duplicate(true)
    for id in SNAP_FIELDS:set(id,copy[id])
    player.load_checkpoint(copy.player)
    # The only post-begin use of control is its stateless XY contact query.
    # Reconstruct an independent oracle, never restore a live Training actor.
    if control==null:control=Training.new()
