extends RefCounted
## Standalone reference-driven clip. No legacy L as pose source.
## Existing Spatial FK, two-link IK, support and MotionEntry remain unchanged.
## Visual experiment; contact events are diagnostics only.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const IK=preload("res://lab/spatial_lab/spatial_ik.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Transition=preload("res://lab/spatial_lab/spatial_transition.gd")
const Training=preload("res://lab/training_control.gd")
const Keys=preload("res://lab/spatial_lab/double_spin_keys_009.gd")
var player=Transition.new()
var desired=FK.new()
var oracle=Training.new()
var initial:Dictionary={}
var guard:Dictionary={}
var pose:Dictionary={}
var origin_x:float=0.
var ground_y:float=0.
var start_yaw:int=0
var direction:int=1
var striking:int=0
var anime:bool=false
var age:int=0
var active:bool=false
var contact_side:int=-1
var anchor:=Vector3.ZERO
var fired:bool=false
var diagnostic:Dictionary={}
var previous_tip:=Vector3.ZERO
var air_frames:int=0
var switches:int=0
var incoming_air:bool=false

func strike_tip()->Vector3:
    var side:String=Support.SIDES[striking]
    return player.rig.point3("knee_"+side).lerp(player.rig.point3("foot_"+side),.9)

func begin(source,side:int,style:bool,yaw:int=0)->bool:
    if active or side not in [0,1]:return false
    player=Transition.new()
    striking=side
    direction=1 if side==0 else -1
    anime=style
    start_yaw=yaw
    origin_x=source.walker.x
    initial=source.walker.pose.duplicate(true)
    initial.root[0]+=origin_x
    guard=Training.new().walker.pose.duplicate(true)
    guard.root[0]+=origin_x
    desired.lift_legacy(initial,yaw)
    var prior:Dictionary={}
    if not source.walker.previous_pose.is_empty():
        var before:Dictionary=source.walker.previous_pose.duplicate(true)
        before.root[0]+=origin_x-source.walker.ground_speed/60.
        var prev=FK.new()
        prev.lift_legacy(before,yaw)
        prior=Entry.sample(prev,before)
    player.seed(desired,initial,prior)
    contact_side=1-striking if bool(source.walker.paths[1-striking].stance) else -1
    if contact_side<0 and bool(source.walker.paths[striking].stance):contact_side=striking
    incoming_air=contact_side<0
    ground_y=0.
    if contact_side>=0:
        var s:String=Support.SIDES[contact_side]
        player.contact(s,Support.PIVOT)
        anchor=player.support.contacts[s].anchor
        ground_y=anchor.y
    player.command(5)
    var q:Dictionary=player.step(Entry.sample(desired,initial))
    if not q.accepted:return false
    pose=q.pose
    age=0
    active=true
    fired=false
    diagnostic={}
    switches=0
    air_frames=0
    previous_tip=strike_tip()
    return true

func translate(delta:Vector3)->void:
    for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+delta

# Solve each free leg to an authored hip-relative spatial goal. Pole follows
# the body frame; blend at entry and end back to the lifted actual guard.
func leg_goal(side:String,goal:Vector3,pole:Vector3)->void:
    var h:String="thigh_"+side
    var k:String="knee_"+side
    var f:String="foot_"+side
    var hip:Vector3=desired.point3(h)
    var a:float=desired.rest_offset_xyz(k).length()
    var b:float=desired.rest_offset_xyz(f).length()
    var axis:Vector3=(goal-hip).normalized()
    if axis.length_squared()<.000001:axis=Vector3.DOWN
    var q:Dictionary=IK.solve(hip,goal,a,b,axis,pole)
    var upper:Vector3=Vector3(q.knee)-hip
    var lower:Vector3=Vector3(q.ankle)-Vector3(q.knee)
    var normal:Vector3=upper.cross(lower).normalized()
    desired.joint_xyz[k]=q.knee
    desired.joint_xyz[f]=q.ankle
    desired.joint_basis[h]=IK.bone_frame(desired.rest_offset_xyz(k),upper,normal)
    desired.joint_basis[k]=IK.bone_frame(desired.rest_offset_xyz(f),lower,normal)
    desired.joint_basis[f]=Support.foot_frame(desired,pose,side)

func selected_contact(t:int)->int:
    if t<4:return contact_side
    if t<Keys.TAKEOFF:return 1-striking
    if t<Keys.LAND:return -1
    if t<Keys.TRANSFER:return striking
    return 1-striking

func step()->Dictionary:
    if not active:return {"accepted":false,"reason":"inactive"}
    var next:int=age+1
    var old_state:Dictionary=checkpoint()
    var v:Dictionary=Keys.sample(float(next),anime)
    var yaw:int=start_yaw+direction*roundi(float(v.yaw)*65536./360.)
    var frame:Basis=FK.yaw_basis(yaw)
    var gain:float=smoothstep(0.,5.,float(next))*(1.-smoothstep(55.,60.,float(next)))
    var p:Dictionary=(initial if next<6 else guard).duplicate(true)
    p.angles.hips=lerpf(float(p.angles.get("hips",0.)),float(v.lean),gain)
    p.angles.chest=lerpf(float(p.angles.get("chest",0.)),float(v.chest),gain)
    p.angles.head=lerpf(float(p.angles.get("head",0.)),-float(v.lean)*.65,gain)
    # Spatial yaw supplies the turn; no reuse of the legacy yaw as rotation.
    p.angles.pelvis_turn=lerpf(float(p.angles.get("pelvis_turn",45.)),45.,gain)
    p.angles.shoulder_turn=lerpf(float(p.angles.get("shoulder_turn",32.)),32.,gain)
    var a:Array=v.arms
    for i in 2:
        var role:int=striking if i==0 else 1-striking
        var s:String=Support.SIDES[role]
        p.angles["shoulder_"+s]=lerpf(float(p.angles["shoulder_"+s]),float(a[i*2]),gain)
        p.angles["elbow_"+s]=lerpf(float(p.angles["elbow_"+s]),float(a[i*2+1]),gain)
        p.angles["foot_pitch_"+s]=lerpf(float(p.angles["foot_pitch_"+s]),-18. if i==0 and next>=40 and next<=47 else 0.,gain)
    pose=p
    desired.evaluate_spatial(p,yaw,0.,direction*roundi(float(v.twist)*gain*65536./360.),direction*roundi(float(v.shoulder_twist)*gain*65536./360.),{},true)
    for i in 2:
        var role:int=striking if i==0 else 1-striking
        var s:String=Support.SIDES[role]
        var hip:Vector3=desired.point3("thigh_"+s)
        var old:Vector3=desired.point3("foot_"+s)
        var reach:float=desired.rest_offset_xyz("knee_"+s).length()+desired.rest_offset_xyz("foot_"+s).length()
        var relative:Vector3=v.strike if i==0 else v.other
        relative.z*=direction
        var goal:Vector3=old.lerp(hip+frame*relative*reach,gain)
        if gain>.0001:leg_goal(s,goal,frame*Vector3.RIGHT)
    # Position the desired pelvis near the previous solved pelvis. Supported
    # motion then orbits around a fixed world toe; flight advances freely.
    var last_hip:Vector3=player.rig.point3("hips")
    var hip_now:Vector3=desired.point3("hips")
    translate(Vector3(last_hip.x-hip_now.x,0.,last_hip.z-hip_now.z))
    var wanted:int=selected_contact(next)
    if wanted<0:
        var low:float=maxf(Support.toe(desired,p,"near").y,Support.toe(desired,p,"far").y)
        var lift:float=float(v.clearance) if next>=Keys.TAKEOFF else maxf(.2,ground_y-maxf(Support.toe(player.rig,old_state.pose,"near").y,Support.toe(player.rig,old_state.pose,"far").y))
        translate(Vector3(.26 if anime else .18,ground_y-low-lift,0.))
    else:
        var support_name:String=Support.SIDES[wanted]
        var toe:Vector3=Support.toe(desired,p,support_name)
        if wanted!=contact_side:
            # Explicit new touchdown from the current desired spatial pose.
            # Capture the new anchor at ground height; never carry old toe
            # through flight or silently change an existing anchor.
            translate(Vector3(0.,ground_y-toe.y,0.))
            player.support.contacts.clear()
            player.support.capture(desired,p,support_name,Support.PIVOT)
            anchor=player.support.contacts[support_name].anchor
            switches+=1
        else:
            translate(anchor-toe)
        # Keep the unplanted toe out of the ground plane. It is not a
        # contact; at the end it can meet the ground for a stable stance.
        var free:String=Support.SIDES[1-wanted]
        var free_toe:Vector3=Support.toe(desired,p,free)
        if free_toe.y>ground_y or next>=56:
            var free_foot:Vector3=desired.point3("foot_"+free)
            free_foot.y+=ground_y-free_toe.y
            leg_goal(free,free_foot,frame*Vector3.RIGHT)
    if wanted<0:
        if contact_side>=0:switches+=1
        player.support.contacts.clear()
    contact_side=wanted
    Entry.update_xy(desired)
    var q:Dictionary=player.step(Entry.sample(desired,p))
    if not q.accepted:
        load_checkpoint(old_state)
        return q
    pose=q.pose
    age=next
    if contact_side<0:air_frames+=1
    var tip:Vector3=strike_tip()
    if not fired and age>=Keys.HIT-1:
        var hit:bool=oracle.contact(Vector2(previous_tip.x,previous_tip.y),Vector2(tip.x,tip.y))
        if hit or age>=Keys.HIT+2:
            fired=true
            diagnostic={"tick":age,"hit":hit,"tip":tip}
    previous_tip=tip
    if age==Keys.END:active=false
    q["contact_side"]=contact_side
    q["tip"]=tip
    return q

const STATE=["initial","guard","pose","origin_x","ground_y","start_yaw","direction","striking","anime","age","active","contact_side","anchor","fired","diagnostic","previous_tip","air_frames","switches","incoming_air"]
func checkpoint()->Dictionary:
    var state:Dictionary={}
    for id in STATE:state[id]=get(id)
    state["player"]=player.checkpoint()
    return state.duplicate(true)

func load_checkpoint(state:Dictionary)->void:
    var s:Dictionary=state.duplicate(true)
    for id in STATE:set(id,s[id])
    player.load_checkpoint(s.player)
