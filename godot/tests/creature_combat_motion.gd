extends SceneTree
const C=preload("res://addons/creature/clips.gd")
const W=preload("res://addons/creature/combat.gd")
var failures: int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
func make_world():
    var w=W.new(C.defaults())
    w.a.pos.x=100
    w.b.pos.x=125
    return w
func _run()->void:
    var w=make_world()
    for i in range(40):w.step(1.0/60,{"strike":true},{})
    check(w.a.attacks_started==1 and w.hits==1,"Held attack fires once")
    check(w.freeze_total>.04,"Hitstop actual duration")
    var combo_world=make_world()
    for i in range(100):
        var pressed:bool=i==0 or i==15 or i==34
        combo_world.step(1.0/60,{"strike":pressed},{})
    print("Combo: hits ",combo_world.hits," best ",combo_world.best_combo," starts ",combo_world.a.attacks_started)
    check(combo_world.best_combo>=2 and combo_world.hits>=2,"Confirmed combo followup")
    var miss=make_world()
    miss.b.pos.x=280
    for i in range(24):miss.step(1.0/60,{"strike":i==0 or i==15},{})
    check(miss.hits==0 and miss.a.attacks_started==1,"Whiff cannot cancel")
    var block=make_world()
    for i in range(24):block.step(1.0/60,{"strike":i==0 or i==15},{"guard":true})
    check(block.blocks==1 and block.impacts==0 and block.a.attacks_started==1,"Block cannot confirm cancel")
    var a=make_world()
    var b=make_world()
    for i in range(60):a.step(1.0/60,{"strike":i==0},{})
    for i in range(30):b.step(1.0/30,{"strike":i==0},{})
    check(a.a.pos.distance_to(b.a.pos)<.001 and a.b.hp==b.b.hp and a.sim_steps==b.sim_steps,"Fixed tick combat")
    var old=make_world()
    old.modern=false
    for i in range(40):old.step(1.0/60,{"strike":i==0},{})
    check(old.freeze_total==0 and old.hits==1,"Comparison mode")
    var magic=W.new(C.defaults())
    magic.a.pos.x=100
    magic.b.pos.x=180
    for i in range(60):magic.step(1.0/60,{"cast":i==0},{})
    check(magic.b.hp==80 and magic.hits==1 and magic.freeze_total>.07,"Heavy impact")
    print("Combat dynamics tests failures: ",failures,"; freeze ",w.freeze_total)
    quit(0 if failures==0 else 1)
