extends SceneTree
const C=preload("res://addons/creature/physical_creature.gd")
const T=preload("res://addons/creature/motion_track.gd")
var failures: int=0
func _initialize() -> void:
    create_timer(20).timeout.connect(func():quit(1))
    call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _run() -> void:
    var track: Dictionary=T.defaults()
    check(T.valid(track),"Default motion valid")
    track.keys[2].speed=180
    check(T.save_track(track,"user://test_motion.json"),"Motion save")
    var loaded: Dictionary=T.load_track("user://test_motion.json")
    check(float(loaded.keys[2].speed)==180,"Motion roundtrip")
    loaded.active_to=-1
    check(not T.valid(loaded),"Reject invalid window")
    var boxes: Array[Rect2]=[Rect2(-1000,200,2000,80)]
    var c=C.new(Vector2(100,170),boxes)
    for i in range(120):c.advance(1.0/60,1,false)
    var p: Vector2=c.body.point("front")
    var v: Vector2=c.body.nodes[0].v
    var steps: int=c.body.steps
    check(c.change_tail(1) and c.body.nodes.size()==5,"Grow tail in place")
    check(c.body.nodes[-1].v==c.body.nodes[-2].v,"New tail inherits velocity")
    check(c.change_mass(.25),"Live mass")
    check(c.change_legs(true) and c.limbs.legs.size()==6,"Live extra legs")
    check(c.change_reach(.2),"Live reach")
    check(c.body.point("front")==p and c.body.nodes[0].v==v and c.body.steps==steps,"No reset, position and velocity preserved")
    check(c.attack.set_track(track),"Custom motion applied")
    for i in range(120):c.advance(1.0/60,0,false)
    p=c.body.point("front")
    var target: Dictionary={"id":"test","p":p+Vector2(44,-3),"r":14.0,"hp":100}
    c.attack.targets.append(target)
    c.advance(1.0/60,0,false,false,0,true)
    check(not c.change_legs(false),"No anatomy change during attack")
    for i in range(42):c.advance(1.0/60,0,false)
    check(c.attack.count==1 and not c.attack.active and c.attack.hit_count==1,"Mutated body uses same attack")
    check(c.change_tail(-1) and c.change_legs(false),"Live remove modules")
    for i in range(240):c.advance(1.0/60,-1,false)
    check(c.body.finite() and c.body.penetration()<.05 and c.body.max_error<2,"Mutated body stable")
    print("Evolution tests failures: ",failures,"; mutations ",c.mutations,"; hits ",c.attack.hit_count)
    quit(0 if failures==0 else 1)
