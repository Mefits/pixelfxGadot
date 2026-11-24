extends SceneTree
const C=preload("res://addons/creature/physical_creature.gd")
const A=preload("res://addons/creature/hybrid_attack.gd")
var failures: int=0
func _initialize() -> void:
    create_timer(20.0).timeout.connect(func():quit(1))
    call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _run() -> void:
    var floor_boxes: Array[Rect2]=[Rect2(-1000,200,2000,80)]
    var c=C.new(Vector2(100,170),floor_boxes)
    for i in range(120):c.advance(1.0/60,0,false)
    var start: Vector2=c.body.point("front")
    var target: Dictionary={"id":"dummy","p":start+Vector2(42,-2),"r":13.0,"hp":100}
    c.attack.targets.append(target)
    var min_tilt: float=INF
    var max_tilt: float=-INF
    var max_x: float=start.x
    var valid: int=0
    for i in range(42):
        c.advance(1.0/60,0,false,false,0,i==0)
        var front: Vector2=c.body.point("front")
        var rear: Vector2=c.body.point("rear")
        var tilt: float=front.y-rear.y
        min_tilt=minf(min_tilt,tilt)
        max_tilt=maxf(max_tilt,tilt)
        max_x=maxf(max_x,front.x)
        if c.attack.active and c.attack.valid_pose:
            valid+=1
            check(absf(front.distance_to(c.attack.knee)-c.limbs.upper)<.03,"Attack upper IK length")
            check(absf(c.attack.knee.distance_to(c.attack.tip)-c.limbs.lower)<.03,"Attack lower IK length")
            check(not A.segment_blocked(front,c.attack.knee,floor_boxes,.5) and not A.segment_blocked(c.attack.knee,c.attack.tip,floor_boxes,.5),"Attack chain clear")
            check(not c.limbs.legs[c.attack.leg].planted,"Attack limb not planted")
    print("Hybrid attack: travel ",max_x-start.x," tilt range ",max_tilt-min_tilt," valid frames ",valid," hits ",c.attack.hit_count," peak support ",c.attack.peak_support)
    check(c.attack.count==1 and not c.attack.active and c.limbs.override_leg==-1,"Attack completes and returns ownership")
    check(max_tilt-min_tilt>3 and max_x-start.x>8,"Physical trunk actually animates")
    check(target.hp==80 and c.attack.hit_count==1,"Single hit per target per attack")
    check(valid>20 and c.attack.had_active_support,"Other limbs support during strike")
    for i in range(60):c.advance(1.0/60,0,false)
    check(c.limbs.support_count>=2,"Restore procedural support")
    var wall_boxes: Array[Rect2]=[floor_boxes[0],Rect2(126,40,30,160)]
    var w=C.new(Vector2(100,170),wall_boxes)
    for i in range(120):w.advance(1.0/60,0,false)
    var hidden: Dictionary={"id":"behind","p":Vector2(168,170),"r":15.0,"hp":100}
    w.attack.targets.append(hidden)
    for i in range(42):w.advance(1.0/60,0,false,false,0,i==0)
    check(hidden.hp==100,"No hit through wall")
    check(w.attack.blocked_ticks>0 and w.body.penetration()<.05,"Wall limits attack")
    var air=C.new(Vector2(100,60),floor_boxes)
    var y: float=air.body.point("front").y
    for i in range(18):air.advance(1.0/60,0,false,false,0,i==0)
    check(air.body.point("front").y>y+5 and not air.grounded,"Air attack does not cancel gravity")
    var mirror=C.new(Vector2(200,170),floor_boxes,2,1,true,-1)
    for i in range(120):mirror.advance(1.0/60,0,false)
    var old: float=mirror.body.point("front").x
    for i in range(42):mirror.advance(1.0/60,0,false,false,0,i==0)
    check(mirror.body.point("front").x<old-8,"Mirrored attack")
    print("Hybrid tests failures: ",failures)
    quit(0 if failures==0 else 1)
