extends "res://lab/impact_landing_095.gd"
const Solver=preload("res://lab/ragdoll_solver_097.gd")
var variant:int
var passes:int=28
var impulse_scale:float=1.
var physics_body
var prior_pose:Dictionary={}
var before_launch:Dictionary={}

func _init(r,p:Dictionary,m:int):
    super(r,p,2)
    variant=2
    impulse_scale=[1.,3.,5.][m]
    prior_pose=base.duplicate(true)

func snapshot()->Dictionary:
    var s:Dictionary=super.snapshot()
    s.merge({"passes":passes,"impulse_scale":impulse_scale,"prior_pose":prior_pose.duplicate(true),"before_launch":before_launch.duplicate(true),"physical":physics_body.snapshot() if physics_body!=null else {}})
    return s

func restore(s:Dictionary)->void:
    super.restore(s)
    passes=int(s.passes)
    impulse_scale=float(s.impulse_scale)
    prior_pose=s.prior_pose.duplicate(true)
    before_launch=s.before_launch.duplicate(true)
    physics_body=null
    if not s.physical.is_empty():
        physics_body=Solver.new(rig,flight_entry,before_launch,floor_y,true,Vector2(-70.,-58.)*impulse_scale,-2.4*impulse_scale,variant,passes)
        physics_body.restore(s.physical)
        physics_body.pose()

func strike(id:int,zone:String,push:float,power:float,category:int)->bool:
    if physics_body!=null:return false
    return super.strike(id,zone,push,power,category)

func step()->Dictionary:
    var result:Dictionary
    if state!="AIR" and physics_body==null:
        result=super.step()
        if state=="AIR" and before_launch.is_empty():before_launch=prior_pose.duplicate(true)
        prior_pose=result.pose.duplicate(true)
    else:
        if physics_body==null:
            physics_body=Solver.new(rig,flight_entry,before_launch,floor_y,true,Vector2(-70.,-58.)*impulse_scale,-2.4*impulse_scale,variant,passes)
        flight_pose=physics_body.tick()
        flight_position=IK.root_of(flight_pose)
        support_count=0
        state="PHYS_CONTACT" if physics_body.touched else "AIR"
        clearance=floor_y-bottom()
        tick+=1
        result=air_sample()
    result["physics_contacts"]=physics_body.contact_count if physics_body!=null else 0
    result["touched"]=physics_body.touched if physics_body!=null else false
    result["motor"]=physics_body.motor if physics_body!=null else 0.
    result["physics_anchor_error"]=physics_body.anchor_error if physics_body!=null else 0.
    result["physics_penetration"]=physics_body.penetration if physics_body!=null else 0.
    result["physics_pose_error"]=physics_body.pose_error if physics_body!=null else 0.
    result["physics_peak_speed"]=physics_body.peak_speed if physics_body!=null else 0.
    result["com"]=physics_body.center_of_mass() if physics_body!=null else rig.point("hips")
    result["tone_impulse"]=physics_body.tone_impulse if physics_body!=null else 0.
    result["friction_impulse"]=physics_body.friction_impulse if physics_body!=null else 0.
    return result
