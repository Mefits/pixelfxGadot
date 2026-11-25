extends SceneTree
const C=preload("res://addons/creature/physical_creature.gd")
const T=preload("res://addons/creature/motion_track.gd")
var failures: int=0
func _initialize() -> void:
    create_timer(20).timeout.connect(func():quit(1))
    call_deferred("_run")
func check(ok: bool,msg: String) -> void:
    if not ok:failures+=1;push_error(msg)
func _anatomies()->void:
    var A=preload("res://addons/creature/anatomy.gd")
    var boxes:Array[Rect2]=[Rect2(-1000,200,2000,80)]
    for profile in A.templates():
        check(A.valid(profile),"Anatomy schema "+profile.type)
        var c=C.new(Vector2(100,150),boxes,2,1,true,1.0,profile)
        check(c.body.nodes.size()==2+int(profile.tail)+int(profile.tentacles)*int(profile.tentacle_segments),"Body topology "+profile.type)
        check(c.body.links.size()==c.body.nodes.size()-1,"Tree constraints "+profile.type)
        check(c.limbs.legs.size()==int(profile.leg_count),"Leg count "+profile.type)
        check(c.branches.size()==int(profile.tentacles),"Tentacle count "+profile.type)
        for i in range(120):c.advance(1.0/60,0,false)
        var start:float=c.body.point("front").x
        for i in range(120):c.advance(1.0/60,1,false)
        check(c.body.finite() and c.body.penetration()<.08,"Stable contacts "+profile.type)
        check(c.body.point("front").x>start+15,"Actual locomotion "+profile.type)
        check(A.valid(c.anatomy_snapshot()),"Live anatomy roundtrip "+profile.type)
        if profile.type=="tentacled":
            check(c.change_tail(-1),"Remove tail with branches")
            check(c.body.ids.has("tentacle_1_3") and c.branches.size()==2,"Branches survive tail mutation")
            check(c.body.links.size()==c.body.nodes.size()-1,"Branched graph consistent")
    var invalid:Dictionary=A.defaults()
    invalid.leg_count=7
    check(not A.valid(invalid),"Reject odd leg count")
    invalid=A.defaults()
    invalid.tentacles=99
    check(not A.valid(invalid),"Reject excess branches")

func _physical_abilities()->void:
    var A=preload("res://addons/creature/anatomy.gd")
    var P=preload("res://addons/creature/physical_ability.gd")
    var boxes:Array[Rect2]=[Rect2(-1000,200,2000,80)]
    for p in P.templates():check(P.valid(p),"Physical ability schema "+p.type)
    var profiles:Array=P.templates()
    var c=C.new(Vector2(100,160),boxes,2,1,true,1.0,A.templates()[4])
    for i in range(120):c.advance(1.0/60,0,false)
    var at:Vector2=c.body.point("front")
    var target:Dictionary={"id":"target","p":at+Vector2(29,0),"r":8.0,"hp":100}
    check(c.special.configure(profiles[0]) and c.special.begin(c,target),"Grab begins with compatible branch")
    check(not c.special.begin(c,target),"No overlapping ability")
    for i in range(95):c.advance(1.0/60,0,false)
    check(c.special.hits==1,"Physical tip acquires target")
    check(Vector2(target.p).distance_to(at+Vector2(29,0))>2,"Grab actually pulls")
    check(c.body.finite() and c.body.penetration()<.1,"Grab body remains stable")
    var plain=C.new(Vector2(100,160),boxes)
    check(not P.compatible(profiles[0],plain),"No grab without tentacles")
    for i in range(120):plain.advance(1.0/60,0,false)
    var front:Vector2=plain.body.point("front")
    var enemy:Dictionary={"id":"enemy","p":front+Vector2(60,0),"r":8.0,"hp":100}
    check(plain.special.configure(profiles[3]) and plain.special.begin(plain,enemy),"Bolt launched")
    for i in range(120):plain.advance(1.0/60,0,false)
    check(enemy.hp==78 and plain.special.hits==1,"Swept bolt hits once")
    front=plain.body.point("front")
    enemy.p=front+Vector2(60,0)
    enemy.hp=100
    plain.body.obstacles.append(Rect2(front+Vector2(25,-15),Vector2(8,30)))
    check(plain.special.begin(plain,enemy),"Blocked bolt launched")
    for i in range(100):plain.advance(1.0/60,0,false)
    check(enemy.hp==100,"Wall blocks projectile")
    plain.body.obstacles.assign(boxes)
    check(plain.special.configure(profiles[4]) and plain.special.begin(plain,{}),"Growth uses mutation")
    check(plain.tail_count==3,"Physical tail added")
    for i in range(100):plain.advance(1.0/60,0,false)
    front=plain.body.point("front")
    enemy.p=front+Vector2(35,0)
    check(plain.special.configure(profiles[5]) and plain.special.begin(plain,enemy),"Acid launched")
    for i in range(140):plain.advance(1.0/60,0,false)
    check(enemy.hp==65,"Acid direct hit and four ticks")
    check(plain.body.finite(),"Body finite after abilities")

func _run() -> void:
    _physical_abilities()
    _anatomies()
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
    check(c.change_legs(true) and c.change_legs(true) and c.limbs.legs.size()==8,"Eight legs")
    check(not c.change_legs(true),"Maximum leg count")
    check(c.change_legs(false) and c.change_legs(false) and not c.change_legs(false),"Minimum leg count")
    for i in range(20):c.change_tail(1)
    check(c.tail_count<=12 and c.body.nodes.size()==c.tail_count+2 and c.body.links.size()==c.tail_count+1,"Tail graph consistent")
    for i in range(240):c.advance(1.0/60,1,false)
    check(c.body.finite() and c.body.penetration()<.05,"Long mutated body stable")
    print("Evolution tests failures: ",failures,"; mutations ",c.mutations,"; hits ",c.attack.hit_count)
    quit(0 if failures==0 else 1)
