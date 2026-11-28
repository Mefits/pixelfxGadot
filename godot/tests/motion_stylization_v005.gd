extends SceneTree
const Drive=preload("res://lab/motion_stylization/acceleration_signal.gd")
const Shape=preload("res://lab/motion_stylization/directional_shape.gd")
const Sweep=preload("res://lab/motion_stylization/swept_body.gd")
const Training=preload("res://lab/training_control.gd")
const Body=preload("res://lab/body_ankle_069.gd")
var failures:Array[String]=[]
func check(v:bool,m:String)->void:
    if not v:failures.append(m)
func _initialize()->void:call_deferred("run")
func run()->void:
    var f=Training.new()
    var b=Body.new(2)
    var parts:Array=b.make(f.walker.rig.points,f.walker.pose.angles,f.walker.rig.rotations.head)
    var drive=Drive.new()
    var shape=Shape.new()
    for anchor in ["hand_far","foot_near"]:
        drive.reset()
        drive.sample(0,"strike",anchor,false,Vector2.ZERO,Vector2.ZERO)
        drive.sample(1,"strike",anchor,false,Vector2(5,0),Vector2(5,0))
        check(drive.score==0. and drive.trail().is_empty(),"chamber clean")
        drive.sample(2,"strike",anchor,true,Vector2(10,3),Vector2(10,3))
        check(drive.onset_tick==2 and drive.onset_world==Vector2(5,0),"onset stored")
        var origin:Vector2=drive.onset_world
        drive.sample(3,"strike",anchor,true,Vector2(16,6),Vector2(16,6))
        check(drive.onset_world==origin and drive.trail().size()>1,"origin stable")
        var before:Array=parts.duplicate(true)
        var ids:Array=Sweep.indices(anchor)
        for curved in [false,true]:
            var out:Array=shape.build(parts,drive,curved)
            check(shape.changed and out.size()==parts.size(),"one body "+anchor)
            check(parts==before,"source unchanged")
            check(out[ids[0]].a==parts[ids[0]].a and out[ids[1]].b==parts[ids[1]].b,"endpoints")
            check(out[ids[2]]==parts[ids[2]],"terminal unchanged")
        drive.sample(4,"strike",anchor,false,Vector2(18,6),Vector2(18,6))
        check(shape.build(parts,drive,true)==parts and drive.trail().is_empty(),"impact clean")
    print("MOTION_STYLIZATION_V005 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
