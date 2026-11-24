extends SceneTree
const W=preload("res://game/world.gd")
const M=preload("res://game/motor.gd")
const R=preload("res://game/rig.gd")
var errors:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:errors+=1;push_error(msg)
func _run()->void:
    var w=W.new()
    var a:Dictionary=w.rig_a.points
    var b:Dictionary=w.rig_b.points
    for id in a:
        var l:Vector2=a[id]-w.a.pos
        var r:Vector2=b[id]-w.b.pos
        check(l.distance_to(Vector2(-r.x,r.y))<.001,"Mirrored joint "+id)
    for i in range(120):
        w.tick({"move":1},{})
        var p:Dictionary=w.rig_a.points
        for side in ["near","far"]:
            check(absf(p["thigh_"+side].distance_to(p["knee_"+side])-R.UPPER_LEG)<.001,"Upper leg")
            check(absf(p["knee_"+side].distance_to(p["foot_"+side])-R.LOWER_LEG)<.001,"Lower leg")
            check(p["foot_"+side].y<=M.FLOOR+.01,"No floor penetration")
    check(w.a.pos.x>400 and w.a.steps>2,"Walk and foot steps")
    var before:float=w.a.pos.x
    for i in range(100):w.tick({}, {})
    check(absf(w.a.velocity.x)<.01 and w.a.pos.x-before<12,"Braking")
    check(w.a.swing==-1,"Settled feet")
    var min_y:float=M.FLOOR
    for i in range(180):
        w.tick({"jump":i==0},{})
        min_y=minf(min_y,w.a.pos.y)
    check(min_y<M.FLOOR-65 and w.a.grounded and w.a.pos.y==M.FLOOR,"Jump lands")
    for i in range(240):w.tick({"move":1,"run":true},{})
    check(w.b.pos.x-w.a.pos.x>=37.99,"No crossing on ground")
    check(w.a.facing==1 and w.b.facing==-1,"Face opponent")
    var x=W.new()
    var y=W.new()
    for i in range(60):x.advance(1.0/60,{"move":1},{})
    for i in range(120):y.advance(1.0/120,{"move":1},{})
    check(x.ticks==y.ticks and x.a.pos.distance_to(y.a.pos)<.0001,"Fixed-step replay")
    print("N locomotion failures: ",errors)
    quit(0 if errors==0 else 1)
