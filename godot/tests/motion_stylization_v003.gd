extends SceneTree
const Sweep=preload("res://lab/motion_stylization/swept_body.gd")
const Training=preload("res://lab/training_control.gd")
const Body=preload("res://lab/body_ankle_069.gd")
var failures:Array[String]=[]
func check(v:bool,m:String)->void:
    if not v:failures.append(m)
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var f=Training.new()
    var b=Body.new(2)
    var p:Array=b.make(f.walker.rig.points,f.walker.pose.angles,f.walker.rig.rotations.head)
    var fx=Sweep.new()
    var prior:Array=p.duplicate(true)
    fx.sample(0,"K","foot_near",1,true,false,p,0.,Vector2.ZERO)
    var next:Array=p.duplicate(true)
    for i in [13,17]:
        next[i].a[0]+=4.
        next[i].b[0]+=6.
    fx.sample(1,"K","foot_near",2,true,false,next,0.,Vector2(6,0))
    var copy:Array=next.duplicate(true)
    var mesh:Array=fx.swept(next,0)
    check(mesh.size()>next.size(),"swept geometry generated")
    check(next==copy and p==prior,"no mutation of input")
    check(mesh.slice(0,next.size())==next,"original striking body preserved")
    check(fx.ribbon().size()==2,"paired ribbon edges")
    fx.sample(2,"K","foot_near",3,false,true,next,0.,Vector2(6,0))
    check(fx.swept(next,0)==next and fx.ribbon().is_empty(),"clean accent")
    fx.reset()
    check(fx.history.is_empty(),"reset")
    print("MOTION_STYLIZATION_V003 ",JSON.stringify({"failures":failures}))
    quit(0 if failures.is_empty() else 1)
