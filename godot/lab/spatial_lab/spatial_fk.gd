extends RefCounted
## Spatial Lab 0.01. Explicit opt-in; the accepted 2D rig is delegated unchanged.
## +X arena, +Y down, +Z camera. Positive yaw uses Godot's +Y axis.
const Profile=preload("res://lab/fighter_profile.gd")
const TURN:int=65536
const QUARTER:int=16384
var _legacy=Profile.make_rig(Profile.load_profile())
var _rest:Dictionary={}
var _parents:Dictionary={}
var _order:Array[String]=[]
var joint_xyz:Dictionary={}
var joint_basis:Dictionary={}
var points:Dictionary={}
var yaw_units:int=0
var spatial_enabled:bool=false

func _init()->void:
    # Copy the canonical, unevaluated rest graph once. Never read mutable
    # projected girdle offsets after legacy evaluate().
    for j in _legacy.joints:
        var id:String=j.id
        var off:Vector2=j.offset
        var z:float=off.x if id.begins_with("shoulder_") or id.begins_with("thigh_") else 0.
        _rest[id]=Vector3(off.x,off.y,z)
        _parents[id]=String(j.parent)
        _order.append(id)

func ids_in_order()->Array[String]:
    return _order.duplicate()

func rest_offset_xyz(id:String)->Vector3:
    return _rest[id]

func parent_id(id:String)->String:
    return _parents[id]

static func yaw_basis(units:int)->Basis:
    # Reduce only for trig; retain the signed, unwrapped input in state.
    # Cardinal matrices avoid approximating sin(pi/2) or sin(2*pi).
    var u:int=posmod(units,TURN)
    match u:
        0:return Basis.IDENTITY
        QUARTER:return Basis(Vector3(0,0,-1),Vector3(0,1,0),Vector3(1,0,0))
        QUARTER*2:return Basis(Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
        QUARTER*3:return Basis(Vector3(0,0,1),Vector3(0,1,0),Vector3(-1,0,0))
    return Basis(Vector3.UP,float(u)*TAU/float(TURN))

func point(id:String)->Vector2:
    return points.get(id,Vector2.ZERO)

func point3(id:String)->Vector3:
    return joint_xyz.get(id,Vector3.ZERO)

func evaluate_legacy(pose:Dictionary)->void:
    spatial_enabled=false
    yaw_units=0
    _legacy.evaluate(pose)
    points=_legacy.points.duplicate()
    joint_xyz.clear()
    joint_basis.clear()
    for id in _order:
        var p:Vector2=points[id]
        joint_xyz[id]=Vector3(p.x,p.y,0.)
        joint_basis[id]=Basis(Vector3.BACK,float(_legacy.rotations[id]))

## Spatial angles are local planar flexion in degrees, azimuth is local
## fixed-turn yaw by joint, and chest/shoulder twist are relative fixed turns.
## Girdle-only legacy projection is explicit and does not rotate limb bases.
func evaluate_spatial(pose:Dictionary,full_yaw:int,root_z:float=0.,chest_twist:int=0,shoulder_twist:int=0,azimuth:Dictionary={},legacy_girdle:bool=false)->void:
    spatial_enabled=true
    yaw_units=full_yaw
    points.clear()
    joint_xyz.clear()
    joint_basis.clear()
    var angles:Dictionary=pose.get("angles",{})
    var root:Array=pose.get("root",[0,0])
    var global_yaw:Basis=yaw_basis(full_yaw)
    for id in _order:
        var par:String=_parents[id]
        var off:Vector3=_rest[id]
        var local:=yaw_basis(int(azimuth.get(id,0)))*Basis(Vector3.BACK,deg_to_rad(float(angles.get(id,0.))))
        if par.is_empty():
            joint_xyz[id]=Vector3(float(root[0]),float(root[1]),root_z)+off
            joint_basis[id]=global_yaw*local
        else:
            var pb:Basis=joint_basis[par]
            if id.begins_with("shoulder_"):
                pb=pb*yaw_basis(shoulder_twist)
            if legacy_girdle and (id.begins_with("shoulder_") or id.begins_with("thigh_")):
                # Same continuous projected girdle as rig049. Its angle
                # is NOT a body yaw; use a separate offset-only swivel.
                var channel:String="shoulder_turn" if id.begins_with("shoulder_") else "pelvis_turn"
                var t:float=deg_to_rad(clampf(float(angles.get(channel,0.)),0.,90.))
                var x:float=absf(off.x)*sqrt(2.)*sin(PI*.25-t)
                var z:float=sqrt(maxf(0.,2.*off.x*off.x-x*x))
                var side:float=1. if off.x>0. else -1.
                off=Vector3(side*x,off.y,side*z)
            if id=="chest":
                local=yaw_basis(chest_twist)*local
            joint_xyz[id]=Vector3(joint_xyz[par])+pb*off
            joint_basis[id]=pb*local
        var p:Vector3=joint_xyz[id]
        points[id]=Vector2(p.x,p.y)

## Opt-in adapter for legacy planar poses; not a claim of exact 3D recovery.
func lift_legacy(pose:Dictionary,full_yaw:int=0)->void:
    evaluate_spatial(pose,full_yaw,0.,0,0,{},true)
