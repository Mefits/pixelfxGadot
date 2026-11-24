extends SceneTree
const W=preload("res://game/world.gd")
const M=preload("res://game/motor.gd")
const R=preload("res://game/rig.gd")
const G=preload("res://game/guard_pose.gd")
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
    check(a.knee_near.x>a.thigh_near.x and b.knee_near.x<b.thigh_near.x,"Knees bend toward opponent")
    var idle=W.new()
    var initial_feet:Array[Vector2]=idle.a.feet.duplicate()
    var start_pose:Dictionary=idle.rig_a.points.duplicate(true)
    var low:float=start_pose.hips.y
    var high:float=low
    for i in range(144):
        idle.tick({}, {})
        var p:Dictionary=idle.rig_a.points
        var q:Dictionary=idle.rig_b.points
        check(idle.a.feet==initial_feet and idle.a.swing==-1,"Guard support stays fixed")
        low=minf(low,p.hips.y)
        high=maxf(high,p.hips.y)
        for id in p:
            var l:Vector2=p[id]-idle.a.pos
            var r:Vector2=q[id]-idle.b.pos
            check(l.distance_to(Vector2(-r.x,r.y))<.001,"Guard mirror "+id)
        for side in ["near","far"]:
            check(absf(p["shoulder_"+side].distance_to(p["elbow_"+side])-R.UPPER_ARM)<.001,"Arm length")
            check(absf(p["elbow_"+side].distance_to(p["hand_"+side])-R.LOWER_ARM)<.001,"Forearm length")
            check(p["hand_"+side].x>p["shoulder_"+side].x,"Guard hands forward")
            check(p["hand_"+side].y<p.hips.y-10,"Guard hands raised")
            var idx:int=0 if side=="near" else 1
            check(p["foot_"+side].distance_to(initial_feet[idx]-Vector2(0,2))<.01,"Guard support IK")
    check(high-low>4 and high-low<7,"Guard reference amplitude")
    for id in start_pose:check(start_pose[id].distance_to(idle.rig_a.points[id])<.01,"Seamless loop "+id)
    check(G.sample(0)==G.sample(G.DURATION),"Guard phase wraps")
    for i in range(120):
        var previous:Array[Vector2]=w.a.feet.duplicate()
        var old_swing:int=w.a.swing
        w.tick({"move":1},{})
        for j in range(2):
            if j!=old_swing and j!=w.a.swing:
                check(w.a.feet[j].distance_to(previous[j])<.001,"Planted foot remains fixed")
        var p:Dictionary=w.rig_a.points
        for side in ["near","far"]:
            check(absf(p["thigh_"+side].distance_to(p["knee_"+side])-R.UPPER_LEG)<.001,"Upper leg")
            check(absf(p["knee_"+side].distance_to(p["foot_"+side])-R.LOWER_LEG)<.001,"Lower leg")
            check(p["foot_"+side].y<=M.FLOOR+.01,"No floor penetration")
            var index:int=0 if side=="near" else 1
            if w.a.swing!=index:check(p["foot_"+side].distance_to(w.a.feet[index]-Vector2(0,2))<.5,"IK reaches support")
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
