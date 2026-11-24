extends SceneTree
const R=preload("res://addons/creature/rig.gd")
const C=preload("res://addons/creature/clips.gd")
const W=preload("res://addons/creature/combat.gd")
var failures: int=0
func _initialize() -> void:
    call_deferred("_run")
func check(v: bool,msg: String) -> void:
    if not v:failures+=1;push_error(msg)
func _run() -> void:
    var bank: Dictionary=C.defaults()
    check(C.valid(bank),"Default bank invalid")
    var rig=R.humanoid()
    rig.evaluate(C.pose())
    var target: Vector2=rig.point("shoulder_near")+Vector2(14,9)
    var p: Dictionary=rig.solve_ik(C.pose(),"hand_near",target,32)
    rig.evaluate(p)
    check(rig.point("hand_near").distance_to(target)<.2,"IK convergence")
    for j in rig.joints:
        if not j.parent.is_empty():
            check(absf(rig.point(j.id).distance_to(rig.point(j.parent))-Vector2(j.offset).length())<.001,"Bone length")
    check(rig.add_joint("tail0","hips",Vector2(-8,0)),"Extra joint")
    check(rig.add_joint("tail1","tail0",Vector2(-8,0),"hips"),"Extra tail")
    check(not rig.add_joint("bad","missing",Vector2.ONE),"Invalid parent")
    rig.evaluate(C.pose({"tail0":30}))
    check(rig.point("tail1").distance_to(rig.point("tail0"))>7.99,"Extra limb FK")
    check(C.sample(bank.idle,1.2,false)==bank.idle.keys[-1].pose,"Editor endpoint")
    var clip: Dictionary=bank.strike
    C.put_key(clip,.1,C.pose({"chest":10}))
    check(clip.keys.size()==5,"Insert key")
    check(C.events_between(clip,.19,.21).size()==1,"Event crossing")
    check(C.events_between(clip,.21,.22).is_empty(),"No event duplication")
    check(C.save_bank(bank,"user://creature_test.json"),"Save")
    var loaded: Dictionary=C.load_bank("user://creature_test.json")
    check(loaded.strike.keys.size()==5,"Load saved key")
    var w=W.new(C.defaults())
    w.a.pos.x=100
    w.b.pos.x=125
    for i in range(40):w.step(1.0/60,{"strike":i==0},{})
    check(w.b.hp<100 and w.hits==1,"Strike damages exactly once")
    w=W.new(C.defaults())
    w.a.pos.x=100
    w.b.pos.x=180
    for i in range(60):w.step(1.0/60,{"cast":i==0},{})
    check(w.b.hp==80 and w.hits==1,"Cast damages exactly once")
    w=W.new(C.defaults())
    w.a.pos.x=100
    w.b.pos.x=180
    for i in range(60):w.step(1.0/60,{"cast":i==0},{"guard":true})
    check(w.b.hp==95,"Guard reduces damage")
    w=W.new(C.defaults())
    for i in range(30):w.step(1.0/60,{"jump":i==0},{})
    check(w.a.pos.y<=146,"Jump/floor")
    print("Creature rig, arbitrary limb, IK, timeline, persistence and combat failures: ",failures)
    quit(0 if failures==0 else 1)
