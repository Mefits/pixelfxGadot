extends SceneTree
const C=preload("res://addons/creature/clips.gd")
const W=preload("res://addons/creature/combat.gd")
var failures:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
func _run()->void:
    var bank:Dictionary=C.defaults()
    check(C.valid(bank) and bank.size()==12,"Extended bank valid")
    var old:Dictionary=bank.duplicate(true)
    for name in ["cross","heavy","kick","air_strike","hurt_heavy"]:old.erase(name)
    check(C.valid(old) and C.complete(old).size()==12,"Old bank migrated")
    check(C.save_bank(old,"user://legacy_combat_bank.json"),"Save old bank")
    var loaded:Dictionary=C.load_bank("user://legacy_combat_bank.json")
    check(loaded.size()==12 and loaded.strike.keys.size()==old.strike.keys.size(),"Load old bank")
    for spec in [["heavy",25],["kick",17]]:
        var w=W.new(bank)
        w.a.pos.x=100
        w.b.pos.x=125
        var reaction:bool=false
        var anchor:String=""
        for i in range(180):
            w.step(W.DT,{spec[0]:i==0},{})
            if w.b.state=="hurt_heavy":reaction=true
            for e in w.a.events:
                anchor=e.anchor
                if e.kind=="strike" and w.hitstop<=0:
                    print("Marker ",spec[0]," hand ",e.world_anchor," target ",w.b.point("chest")," src chest ",e.world_chest)
        print(spec[0]," damage ",100-w.b.hp," freeze ",w.freeze_total," reaction ",reaction," anchor ",anchor)
        check(w.a.attacks_started==1 and w.hits==1 and w.b.hp==100-int(spec[1]),"Attack "+spec[0])
        if spec[0]=="heavy":check(reaction and w.freeze_total>.10,"Heavy reaction and stop")
        else:check(anchor=="foot_near","Foot attack anchor")
    var air=W.new(bank)
    air.a.pos=Vector2(100,129)
    air.a.velocity.y=0
    air.b.pos.x=125
    air.step(1.0/60,{"strike":true},{})
    check(air.a.state=="air_strike","Air attack selected")
    var y:float=air.a.pos.y
    for i in range(40):air.step(1.0/60,{},{})
    print("Air attack: hits ",air.hits," hp ",air.b.hp," y ",air.a.pos.y)
    check(air.a.pos.y>y and air.a.pos.y<=146,"Air attack preserves gravity")
    check(air.hits==1 and air.b.hp==85,"Air attack connects")
    var saved:Dictionary=bank.duplicate(true)
    saved.cross.events=[]
    var custom=W.new(saved)
    custom.a.pos.x=100
    custom.b.pos.x=125
    for i in range(80):custom.step(1.0/60,{"strike":i==0 or i==15},{})
    check(custom.a.attacks_started==2 and custom.hits==1,"Edited cross respected")
    print("Combat variety failures: ",failures)
    quit(0 if failures==0 else 1)
