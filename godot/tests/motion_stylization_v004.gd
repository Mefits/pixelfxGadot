extends SceneTree
const Sweep=preload("res://lab/motion_stylization/swept_body.gd")
const Seamless=preload("res://lab/motion_stylization/seamless_smear.gd")
const Training=preload("res://lab/training_control.gd")
const Body=preload("res://lab/body_ankle_069.gd")
var failures:Array[String]=[]
func check(v:bool,m:String)->void:
    if not v:failures.append(m)
func _initialize()->void:call_deferred("run")
func run()->void:
    var f=Training.new()
    var b=Body.new(2)
    var p:Array=b.make(f.walker.rig.points,f.walker.pose.angles,f.walker.rig.rotations.head)
    var fx=Sweep.new()
    var sm=Seamless.new()
    for anchor in ["foot_near","hand_far"]:
        fx.reset()
        var ids:Array=fx.indices(anchor)
        var idx:int=int(ids[1])
        var before:Array=p.duplicate(true)
        fx.sample(0,"test",anchor,1,true,false,p,0.,Vector2.ZERO)
        var next:Array=p.duplicate(true)
        next[idx].a[0]+=4.
        next[idx].b[0]+=8.
        fx.sample(1,"test",anchor,2,true,false,next,0.,Vector2(8,0))
        var copy:Array=next.duplicate(true)
        var mesh:Array=sm.build(next,fx)
        check(sm.changed and sm.extension>.18,"actual deformation "+anchor)
        check(mesh.size()==next.size(),"no additional primitives")
        check(next==copy and p==before,"no input mutation")
        check(mesh[idx].a==next[idx].a and mesh[idx].b==next[idx].b,"endpoints unchanged")
        check(mesh[int(ids[-1])]==next[int(ids[-1])],"terminal unchanged")
        check(mesh[idx].part_id==next[idx].part_id,"ownership preserved")
        check(sm.offset_segments().size()>0,"offset generated")
        fx.sample(2,"test",anchor,3,false,true,next,0.,Vector2(8,0))
        check(sm.build(next,fx)==next and not sm.changed,"clean accent")
    print("MOTION_STYLIZATION_V004 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
