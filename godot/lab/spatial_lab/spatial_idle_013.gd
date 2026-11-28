extends RefCounted
## Additive E8 motion on the G20 guard, not blending the two absolute poses.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const Mocap=preload("res://lab/spatial_lab/spatial_mocap_010.gd")
const Idle=preload("res://lab/spatial_lab/spatial_idle_012.gd")
const PERIOD:int=48
const GAINS=[0.,1.,.45,.45]
var mode:int=0
var rig=FK.new()
var desired=FK.new()
var pose:Dictionary={}
var base:Dictionary={}
var motion:Array=[]
var root_mean:=Vector3.ZERO
var yaw_mean:float=0.
var refs:Dictionary={}
var max_shift:float=0.
var max_toe_error:float=0.

func setup(art:Dictionary)->void:
    pose=art.duplicate(true)
    var guard=Mocap.new()
    guard.setup(pose)
    assert(guard.evaluate(0,true).accepted)
    base=Entry.sample(guard.rig,pose)
    var e8=Idle.new()
    e8.mode=1
    e8.setup(pose)
    motion.clear()
    root_mean=Vector3.ZERO
    yaw_mean=0.
    for tick in PERIOD:
        assert(e8.idle(tick).accepted)
        var s:Dictionary=Entry.sample(e8.rig,pose)
        motion.append(s)
        root_mean+=Vector3(s.root)/PERIOD
        yaw_mean+=float(s.yaw)/PERIOD
    # Center local delta on the E8 temporal mean, using hemisphere-aligned
    # quaternion average and unit direction average. Do not import its guard.
    refs.clear()
    for id in rig.ids_in_order():
        var first:Quaternion=motion[0].rotations[id]
        var sum:=Quaternion(0.,0.,0.,0.)
        var dir:=Vector3.ZERO
        for s in motion:
            var q:Quaternion=s.rotations[id]
            if q.dot(first)<0.:q=-q
            sum+=q
            if s.dirs.has(id):dir+=Vector3(s.dirs[id])
        refs[id]={"q":sum.normalized(),"dir":dir.normalized()}
    max_shift=0.
    max_toe_error=0.

static func direction_delta(a:Vector3,b:Vector3,w:float)->Quaternion:
    var axis:Vector3=a.cross(b)
    var d:float=clampf(a.dot(b),-1.,1.)
    if axis.length_squared()<.0000001:
        if d>0.:return Quaternion.IDENTITY
        axis=a.cross(Vector3.RIGHT if absf(a.x)<.8 else Vector3.BACK)
    return Quaternion(axis.normalized(),acos(d)*w)

func idle(tick:int)->Dictionary:
    if mode==0:
        Entry.write_exact(rig,base)
        return {"accepted":true}
    var g:float=GAINS[mode]
    var s:Dictionary=motion[posmod(tick,PERIOD)]
    var turn:int=-roundi(15.*65536./360.) if mode==3 else 0
    var yaw:int=int(base.yaw)+roundi((float(s.yaw)-yaw_mean)*g)+turn
    var yaw_frame:Basis=FK.yaw_basis(yaw)
    var align:Basis=FK.yaw_basis(int(base.yaw)-roundi(yaw_mean))
    var drift:Vector3=align*(Vector3(s.root)-root_mean)*g
    # Root is relative to the G20 guard; no source locomotion offset.
    desired.spatial_enabled=true
    desired.yaw_units=yaw
    desired.joint_xyz.clear()
    desired.joint_basis.clear()
    desired.foot_basis_override.clear()
    for id in desired.ids_in_order():
        var par:String=desired.parent_id(id)
        var local:Quaternion=base.rotations[id]
        # Only pelvis/chest/head and arms receive E8 local motion. Legs
        # retain G20 bend preference and are rebuilt by fixed-foot IK.
        var leg:bool=id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_")
        if not leg:
            var delta:Quaternion=(Quaternion(s.rotations[id])*Quaternion(refs[id].q).inverse()).normalized()
            local=(Quaternion.IDENTITY.slerp(delta,g)*local).normalized()
        if par.is_empty():
            desired.joint_xyz[id]=Vector3(base.root)+drift
            desired.joint_basis[id]=yaw_frame*Basis(local)
        else:
            var pb:Basis=desired.joint_basis[par]
            var d:Vector3=base.dirs[id]
            if not leg:d=direction_delta(refs[id].dir,s.dirs[id],g)*d
            desired.joint_xyz[id]=desired.point3(par)+pb*d*desired.rest_offset_xyz(id).length()
            desired.joint_basis[id]=pb*Basis(local)
    # The fixed anchors are the actual two G20 toe references, including
    # their original relative height. Not an assertion of physical sole contact.
    var seed=FK.new()
    Entry.write_exact(seed,base)
    var solver=Support.new()
    for side in Support.SIDES:
        solver.capture(seed,pose,side,Support.FIXED)
        desired.foot_basis_override[side]=Support.foot_frame(seed,pose,side)
    Entry.update_xy(desired)
    var result:Dictionary=solver.resolve_evaluated(rig,desired,8.)
    if not result.accepted:return result
    max_shift=maxf(max_shift,Vector3(result.root_shift).length())
    for side in Support.SIDES:
        max_toe_error=maxf(max_toe_error,Support.toe(rig,pose,side).distance_to(Vector3(base.toes[side])))
    return result
