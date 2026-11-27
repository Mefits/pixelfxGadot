extends RefCounted
const Goals=preload("res://lab/authoring/goals.gd")
var art:Dictionary={}
var goal_report:Dictionary={}
const Grid=preload("precision.gd")
const Gait=preload("gait.gd")
const Support=preload("support.gd")
const LegIK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var rig
var gait
var support
var hz:int
var bank:Dictionary
var guard:Dictionary
var pose:Dictionary
var previous:Dictionary
var paths:Array
var tick:=0
var speed:=1.
var stopped:=false
var settle:=0.
var action:=""
var age:=0
var serial:=0
var duration:=0
var offsets:Dictionary={}
var slopes:Dictionary={}
var recoil:=0.
var recoil_velocity:=0.
var health:=100
var events:Array=[]
var released:Dictionary={}
var landing:Dictionary={}
var anchors:Dictionary={}
var style:=0.

func _init(r,run_clip:Dictionary,motions:Dictionary,guard_angles:Dictionary,rate:int):
    assert(rate in [60,120])
    hz=rate
    rig=r
    bank=motions
    guard=guard_angles
    gait=Gait.new(r,run_clip)
    support=Support.new(r)
    var base:Dictionary=gait.intent()
    pose=base.pose
    paths=base.paths
    Grid.pose(pose)
    prepare_geometry(paths)
    support.resolve(pose,paths)
    previous=pose
    final_pose=pose
    anchors=world_anchors()

func prepare_geometry(goals:Array)->void:
    for path in goals:
        path.toe=Grid.point(path.toe)
        path.pitch=Grid.scalar(path.pitch)

func world_anchors()->Dictionary:
    var result:Dictionary={}
    for side in Leg.SIDES:
        var id:String="hand_"+side
        result[id]=Grid.point(rig.point(id)+Vector2.RIGHT*gait.travel)
        id="foot_"+side
        result[id]=Grid.point(rig.point(id)+LegIK.toe_vector(final_pose,side)+Vector2.RIGHT*gait.travel)
    return result

# One command per tick: target speed, optional action edge, signed chest
# impulse, static opponent hurt-circle. Combat rules own impulse and damage.
func step(cmd:Dictionary)->void:
    events=[]
    var scale:=60./hz
    var target:float=clampf(cmd.speed,0.,Gait.RUN_SPEED)
    speed=move_toward(speed,maxf(1.,target),.035*scale)
    if target>0.:stopped=false
    if not stopped:
        gait.move_distance(speed,speed*scale)
    var old_paths:=paths
    var base:Dictionary=gait.intent()
    paths=base.paths
    if target==0. and speed<=1. and paths[0].stance and paths[1].stance:
        stopped=true
    settle=move_toward(settle,1. if stopped else 0.,scale/12.)
    style=base.gait
    var dest:Dictionary=base.pose
    for id in guard:
        dest.angles[id]=lerpf(dest.angles[id],guard[id],settle)
    for path in paths:path.pitch=lerpf(path.pitch,0.,settle)
    dest.root[1]=lerpf(dest.root[1],2.5,settle)
    prepare_geometry(paths)
    var next:String=cmd.get("action","")
    if action!="" and bank[action].get("loop",false) and age>=bank[action].frames.size():age=0
    var change:bool=bank.has(next) or (action!="" and age>=bank[action].frames.size())
    if change:
        landing.clear()
        for i in 2:
            var side:String=Leg.SIDES[i]
            if released.has(side) or old_paths[i].get("landing",false):
                landing[side]=[anchors["foot_"+side],old_paths[i].pitch]
        action=next if bank.has(next) else ""
        serial+=1
        age=0
    if action!="":
        dest.angles.merge(bank[action].frames[age],true)
        if bank[action].has("roots") and age<bank[action].roots.size():
            dest.root[0]+=bank[action].roots[age][0]
            dest.root[1]+=bank[action].roots[age][1]
    goal_report.clear()
    var active_goals:Array=[] if art.is_empty() else art.programs.get(action,[])
    if not active_goals.is_empty():Goals.resolve(self,dest,paths,false,active_goals)
    # Signed, damped reaction. Strip the already-applied reaction from
    # transition history via the unlayered pose kept below.
    if change:
        Grid.pose(dest)
        offsets.clear()
        slopes.clear()
        var magnitude:=0.
        for id in guard:
            offsets[id]=wrapf(pose.angles[id]-dest.angles[id],-180.,180.)
            slopes[id]=wrapf(pose.angles[id]-previous.angles[id],-180.,180.)
            if action!="" and bank[action].frames.size()>1 and bank[action].frames[0].has(id):
                slopes[id]-=wrapf(bank[action].frames[1][id]-bank[action].frames[0][id],-180.,180.)
            magnitude=maxf(magnitude,absf(offsets[id]))
        duration=roundi(clampf(4.+magnitude/18.,4.,14.)/scale)
        if action!="":
            for marker_tick in bank[action].markers:duration=mini(duration,marker_tick)
    if age<duration:
        var u:=float(age)/duration
        for id in offsets:
            dest.angles[id]+=offsets[id]*(1.-smoothstep(0.,1.,u))+clampf(slopes[id]*duration,-45.,45.)*u*(1.-u)*(1.-u)
    released=bank[action].feet[age] if action!="" else {}
    for i in 2:
        var side:String=Leg.SIDES[i]
        var path:Dictionary=paths[i]
        if released.has(side):
            var influence:Array=released[side]
            path.toe=Grid.point(Vector2(path.toe).lerp(influence[1],influence[0]))
            path.pitch=Grid.scalar(lerpf(path.pitch,influence[2],influence[0]))
            path.stance=false
        if landing.has(side) and age<duration:
            var u:=smoothstep(0.,float(duration),float(age))
            path.toe=Grid.point((Vector2(landing[side][0])-Vector2.RIGHT*gait.travel).lerp(path.toe,u))
            path.pitch=Grid.scalar(lerpf(landing[side][1],path.pitch,u))
            path.stance=false
            path.landing=true
    Grid.pose(dest)
    previous=pose
    pose=dest
    recoil_velocity+=float(cmd.get("impulse",0.))
    if cmd.has("impact"):
        var impact:Dictionary=cmd.impact
        # Gameplay controls gain and cap. The lever arm sets signed torque.
        var lever:Vector2=Grid.point(rig.point(impact.joint)-rig.point("chest"))
        recoil_velocity+=Grid.scalar(clampf(lever.cross(impact.force)*impact.gain,-impact.cap,impact.cap))
    recoil_velocity+=(-240.*recoil-30.*recoil_velocity)/hz
    recoil+=recoil_velocity/hz
    # Pose history stores the authored layer; final rig contains reaction.
    var resolved:Dictionary=pose.duplicate(true)
    resolved.angles.chest+=recoil
    if not active_goals.is_empty():Goals.resolve(self,resolved,paths,true,active_goals)
    support.resolve(resolved,paths)
    final_pose=resolved
    var current:=world_anchors()
    if action!="" and bank[action].markers.has(age):
        var ordinal:=0
        for marker in bank[action].markers[age]:
            var id:String=marker.anchor
            var hit:=false
            if anchors.has(id) and cmd.has("hurt_center"):
                var start:Vector2=anchors[id]
                var delta:Vector2=current[id]-start
                var u:=clampf((cmd.hurt_center-start).dot(delta)/maxf(delta.length_squared(),1e-12),0.,1.)
                hit=(start+u*delta).distance_to(cmd.hurt_center)<=cmd.radius
            if marker.kind!="strike":hit=false
            if hit:health-=5
            events.append([tick,serial,ordinal,id,hit,marker.kind])
            ordinal+=1
    anchors=current
    age+=1
    tick+=1

var final_pose:Dictionary
# S[t] is immediately before command t. Fixed field order, lossless local
# Variant encoding. Immutable assets and derived render geometry stay outside.
func save()->PackedByteArray:
    var state:=[2,hz,tick,gait.snapshot(),speed,stopped,settle,action,age,serial,duration,offsets,slopes,recoil,recoil_velocity,health,anchors,pose,previous,final_pose,paths,style,released,landing]
    if not art.is_empty():state.append(art.signature)
    return var_to_bytes(state)

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    if s[0]!=2 or s[1]!=hz or (s.size()==24)!=art.is_empty() or (not art.is_empty() and s[24]!=art.signature):
        push_error("Incompatible motion snapshot")
        return
    goal_report.clear()
    tick=s[2]
    gait.restore(s[3])
    speed=s[4]
    stopped=s[5]
    settle=s[6]
    action=s[7]
    age=s[8]
    serial=s[9]
    duration=s[10]
    offsets=s[11]
    slopes=s[12]
    recoil=s[13]
    recoil_velocity=s[14]
    health=s[15]
    anchors=s[16]
    pose=s[17]
    previous=s[18]
    final_pose=s[19]
    paths=s[20]
    style=s[21]
    released=s[22]
    landing=s[23]
    events=[]
    rig.evaluate(final_pose)
