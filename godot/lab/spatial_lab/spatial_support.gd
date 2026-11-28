extends RefCounted
## Spatial contact transaction. FK remains the source of desired animation.
## Solve on a scratch rig; publish only a complete compatible pose.
## Anchor = authored toe reference, NOT physical sole or collision geometry.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const IK=preload("res://lab/spatial_lab/spatial_ik.gd")
const SIDES=["near","far"]
const TOE:=Vector3(4.,0.,0.)
const TOL:float=.001
const FREE:int=0
const PIVOT:int=1
const FIXED:int=2
var contacts:Dictionary={}
var scratch=FK.new()
var last_yaw:int=0

static func sole_basis(yaw:int,pitch:float)->Basis:
    return FK.yaw_basis(yaw)*Basis(Vector3.BACK,deg_to_rad(pitch))

static func foot_frame(r,pose:Dictionary,side:String)->Basis:
    if r.foot_basis_override.has(side):return r.foot_basis_override[side]
    return sole_basis(r.yaw_units,float(pose.get("angles",{}).get("foot_pitch_"+side,0.)))

static func toe(r,pose:Dictionary,side:String)->Vector3:
    return r.point3("foot_"+side)+foot_frame(r,pose,side)*TOE

func capture(r,pose:Dictionary,side:String,mode:int)->void:
    assert(r.spatial_enabled and side in SIDES and mode in [FREE,PIVOT,FIXED])
    if mode==FREE:
        contacts.erase(side)
        return
    var hip:Vector3=r.point3("thigh_"+side)
    var knee:Vector3=r.point3("knee_"+side)
    var ankle:Vector3=r.point3("foot_"+side)
    var axis:Vector3=(ankle-hip).normalized()
    var frame:Basis=foot_frame(r,pose,side)
    # Preserve actual foot orientation on mode switch. Pivot turns about
    # world Y relative to this captured basis, fixed preserves it completely.
    var hint:Vector3=knee-hip
    if (hint-axis*hint.dot(axis)).length_squared()<IK.EPS:
        hint=r.joint_basis["thigh_"+side]*Vector3.LEFT
    contacts[side]={"mode":mode,"anchor":ankle+frame*TOE,"basis":frame,"capture_yaw":r.yaw_units,"axis":axis,"pole":IK.perpendicular(axis,hint),"pole_yaw":r.yaw_units}

func target_frame(c:Dictionary,yaw:int)->Basis:
    var frame:Basis=c.basis
    if c.mode==PIVOT:return FK.yaw_basis(yaw-int(c.capture_yaw))*frame
    return frame

func resolve(r,pose:Dictionary,yaw:int,root_z:float=0.,max_shift:float=8.,chest_twist:int=0,shoulder_twist:int=0,azimuth:Dictionary={},legacy_girdle:bool=true)->Dictionary:
    assert(max_shift>=0.)
    scratch.evaluate_spatial(pose,yaw,root_z,chest_twist,shoulder_twist,azimuth,legacy_girdle)
    var goals:Dictionary={}
    var frames:Dictionary={}
    var shift:=Vector3.ZERO
    # Root feasibility: ordered alternating projection into each leg's
    # reachable shell and a bounded root-displacement ball. Not a mass model.
    for side in SIDES:
        if not contacts.has(side):continue
        var c:Dictionary=contacts[side]
        var frame:Basis=target_frame(c,yaw)
        frames[side]=frame
        goals[side]=Vector3(c.anchor)-frame*TOE
    for iteration in 32:
        for side in SIDES:
            if not goals.has(side):continue
            var center:Vector3=Vector3(goals[side])-scratch.point3("thigh_"+side)
            var delta:Vector3=shift-center
            var a:float=scratch.rest_offset_xyz("knee_"+side).length()
            var b:float=scratch.rest_offset_xyz("foot_"+side).length()
            var distance:float=delta.length()
            var wanted:float=clampf(distance,IK.min_reach(a,b),IK.max_reach(a,b))
            if absf(distance-wanted)>IK.EPS:
                var dir:Vector3=delta.normalized() if distance>IK.EPS else Vector3.UP
                shift=(center+dir*wanted).limit_length(max_shift)
    for id in scratch.ids_in_order():
        scratch.joint_xyz[id]=scratch.point3(id)+shift
    var solved:Dictionary={}
    var max_error:float=0.
    for side in SIDES:
        if not goals.has(side):continue
        var c:Dictionary=contacts[side]
        var hip:Vector3=scratch.point3("thigh_"+side)
        var a:float=scratch.rest_offset_xyz("knee_"+side).length()
        var b:float=scratch.rest_offset_xyz("foot_"+side).length()
        # Transport the prior knee plane with body yaw before adapting
        # to the new target ray. Retain pole at near-straight extension.
        var turn:Basis=FK.yaw_basis(yaw-int(c.pole_yaw))
        var q:Dictionary=IK.solve(hip,goals[side],a,b,turn*Vector3(c.axis),turn*Vector3(c.pole))
        solved[side]=q
        max_error=maxf(max_error,float(q.residual))
    if max_error>TOL:
        return {"accepted":false,"reason":"incompatible_support","root_shift":shift,"max_anchor_error":max_error,"legs":solved}
    # Commit both legs together; failed dual support never partially moves a foot.
    for side in SIDES:
        if not solved.has(side):continue
        var q:Dictionary=solved[side]
        var hip_id:String="thigh_"+side
        var knee_id:String="knee_"+side
        var foot_id:String="foot_"+side
        var upper:Vector3=Vector3(q.knee)-scratch.point3(hip_id)
        var lower:Vector3=Vector3(q.ankle)-Vector3(q.knee)
        var normal:Vector3=upper.cross(lower).normalized()
        scratch.joint_xyz[knee_id]=q.knee
        scratch.joint_xyz[foot_id]=q.ankle
        scratch.joint_basis[hip_id]=IK.bone_frame(scratch.rest_offset_xyz(knee_id),upper,normal)
        scratch.joint_basis[knee_id]=IK.bone_frame(scratch.rest_offset_xyz(foot_id),lower,normal)
        scratch.joint_basis[foot_id]=frames[side]
        scratch.foot_basis_override[side]=frames[side]
        contacts[side].axis=q.axis
        contacts[side].pole=q.pole
        contacts[side].pole_yaw=yaw
    r.joint_xyz=scratch.joint_xyz.duplicate()
    r.joint_basis=scratch.joint_basis.duplicate()
    r.foot_basis_override=scratch.foot_basis_override.duplicate()
    r.points.clear()
    for id in r.ids_in_order():
        var p:Vector3=r.point3(id)
        r.points[id]=Vector2(p.x,p.y)
    r.yaw_units=yaw
    r.spatial_enabled=true
    last_yaw=yaw
    return {"accepted":true,"reason":"","root_shift":shift,"max_anchor_error":max_error,"legs":solved}
