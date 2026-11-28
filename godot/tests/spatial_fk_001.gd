extends SceneTree
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Profile=preload("res://lab/fighter_profile.gd")
const Training=preload("res://lab/training_control.gd")
var failures:Array[String]=[]
var max_length_error:float=0.
var max_adapter_error:float=0.
var max_turn_error:float=0.
var samples:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    if not ok and not failures.has(message):failures.append(message)
func lengths(r)->void:
    for id in r.ids_in_order():
        var par:String=r.parent_id(id)
        var p:Vector3=r.point3(id)
        var basis:Basis=r.joint_basis[id]
        check(p.is_finite() and basis.is_finite(),"finite joint/basis")
        check(absf(basis.determinant()-1.)<.0001,"orthonormal proper basis")
        check(r.point(id)==Vector2(p.x,p.y),"exact XY projection")
        if par.is_empty():continue
        var error:float=absf(p.distance_to(r.point3(par))-r.rest_offset_xyz(id).length())
        max_length_error=maxf(max_length_error,error)
        check(error<.0001,"fixed length "+id)
func compare_legacy(r,legacy,pose:Dictionary)->void:
    legacy.evaluate(pose)
    r.evaluate_legacy(pose)
    check(not r.spatial_enabled and r.points==legacy.points,"bit-exact delegated legacy XY")
    r.lift_legacy(pose)
    lengths(r)
    for id in r.ids_in_order():
        var error:float=r.point(id).distance_to(legacy.point(id))
        max_adapter_error=maxf(max_adapter_error,error)
        check(error<.0001,"lift XY tolerance "+id)
    samples+=1
func run()->void:
    var r=FK.new()
    var legacy=Profile.make_rig(Profile.load_profile())
    var expected:Array=[]
    for j in legacy.joints:expected.append(j.id)
    check(r.ids_in_order()==expected and expected.size()==15,"stable anatomical IDs")
    var pose:Dictionary={"root":[3.,-2.],"angles":{"hips":17.,"chest":-13.,"shoulder_near":22.,"elbow_near":-50.,"thigh_far":-30.,"knee_far":60.}}
    r.evaluate_spatial(pose,0,4.)
    var baseline:Dictionary=r.joint_xyz.duplicate()
    var pivot:Vector3=r.point3("hips")
    var rest:Dictionary={}
    for id in expected:rest[id]=r.rest_offset_xyz(id)
    for u in [0,16384,32768,49152,65536,-16384,-32768,-49152,-65536,131072+16384,-131072-16384]:
        r.evaluate_spatial(pose,u,4.)
        check(r.yaw_units==u,"unwrapped signed yaw")
        lengths(r)
        for id in expected:
            var q:Vector3=baseline[id]-pivot
            var want:Vector3=q
            match posmod(u,65536):
                16384:want=Vector3(q.z,q.y,-q.x)
                32768:want=Vector3(-q.x,q.y,-q.z)
                49152:want=Vector3(-q.z,q.y,q.x)
            var error:float=r.point3(id).distance_to(pivot+want)
            max_turn_error=maxf(max_turn_error,error)
            check(error<.0001,"cardinal yaw "+id)
            check(r.rest_offset_xyz(id)==rest[id],"immutable rest")
    r.evaluate_spatial({"root":[0,0]},0)
    check(r.point3("shoulder_near").z>r.point3("shoulder_far").z,"near depth at zero")
    r.evaluate_spatial({"root":[0,0]},32768)
    check(r.point3("shoulder_near").z<r.point3("shoulder_far").z,"depth swaps without renaming")
    r.evaluate_spatial(pose,12345,0.,2345,-4567,{"shoulder_near":9000,"thigh_far":-7777})
    lengths(r)
    var twisted:Vector3=r.point3("hand_near")
    r.evaluate_spatial(pose,12345,0.,2345,-4567)
    check(r.point3("hand_near").distance_to(twisted)>.1,"local azimuth moves limb")
    for t in [0.,15.,45.,70.,90.]:
        pose.angles.pelvis_turn=t
        pose.angles.shoulder_turn=90.-t
        compare_legacy(r,legacy,pose)
    # Real accepted v21 poses: idle, signed run, K and L, sampled without
    # ever feeding spatial state back into the simulation.
    for side in [0,1]:
        var f=Training.new()
        f.walker.travel_limit=1000.
        f.walker.x=-200.
        for tick in 40:
            f.step(-1 if side==0 else 1,true)
            compare_legacy(r,legacy,f.walker.pose)
        for tick in 50:f.step(0)
        for roundhouse in [false,true]:
            var actor=f.round_kick if roundhouse else f.kick
            actor.configure({"leg":side})
            var accepted:bool=f.press_round_kick() if roundhouse else f.press_kick()
            check(accepted,"accepted legacy attack")
            check(actor.striking==side,"forced anatomical side")
            for tick in actor.end_tick:
                f.step(0)
                compare_legacy(r,legacy,f.walker.pose)
    print("SPATIAL_FK_001 ",JSON.stringify({"samples":samples,"max_length_error":max_length_error,"max_adapter_xy_error":max_adapter_error,"max_cardinal_error":max_turn_error,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
