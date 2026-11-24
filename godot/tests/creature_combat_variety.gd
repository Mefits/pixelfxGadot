extends SceneTree
const C=preload("res://addons/creature/clips.gd")
const W=preload("res://addons/creature/combat.gd")
var failures:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
# Independent contact regression: the authored limb can extend past the target,
# but never grant hits behind the attacker or outside the original radius.
func _check_contact_direction(bank: Dictionary)->void:
    for side in [1,-1]:
        for kind in ["strike","cross","heavy","kick","air_strike"]:
            var w=W.new(bank)
            w.a.pos.x=160
            w.a.facing=side
            w.b.pos.x=160+side*18
            w.b.facing=-side
            var target: Vector2=w.b.point("chest")
            var anchor: Vector2=target+Vector2(side*12,0)
            var event: Dictionary={"kind":"strike","anchor":"foot_near" if kind=="kick" else "hand_near","world_anchor":anchor,"world_chest":w.a.point("chest"),"direction":side,"attack_kind":kind,"attack_time":.2,"chain":1}
            var outcomes: Array=[]
            w._event(w.a,w.b,event,outcomes)
            check(outcomes.size()==1,"Point-blank "+kind+" side "+str(side))
            w.b.guard=true
            outcomes.clear()
            w._event(w.a,w.b,event,outcomes)
            check(outcomes.size()==1 and outcomes[0].blocked,"Guard contact "+kind)
            w.b.pos.x=160-side*8
            event.world_anchor=w.b.point("chest")
            outcomes.clear()
            w._event(w.a,w.b,event,outcomes)
            check(outcomes.is_empty(),"No rear hit "+kind)
            w.b.pos.x=160+side*70
            event.world_anchor=w.a.point("chest")
            outcomes.clear()
            w._event(w.a,w.b,event,outcomes)
            check(outcomes.is_empty(),"No distant hit "+kind)

func _ability_regression()->void:
    var A=preload("res://addons/creature/ability.gd")
    var FX=preload("res://addons/creature/vfx_runtime.gd")
    var profile: Dictionary=A.defaults()
    check(A.valid(profile),"Ability profile valid")
    var clip: Dictionary=A.compile(profile)
    check(clip.keys.size()==5 and clip.events.size()==3,"Ability compilation")
    check(is_equal_approx(float(clip.duration),1.02),"Phase total duration")
    check(A.phase_at(profile,.1)=="charge" and A.phase_at(profile,.4)=="dash" and A.phase_at(profile,.7)=="contact" and A.phase_at(profile,.8)=="recovery","Phase transitions")
    var altered: Dictionary=profile.duplicate(true)
    altered.phases[0].duration=.5
    check(is_equal_approx(float(A.compile(altered).duration),1.2),"Retimed ability")
    check(A.save_profile(altered,"user://test_ability.json"),"Save ability profile")
    check(is_equal_approx(float(A.load_profile("user://test_ability.json").phases[0].duration),.5),"Load ability profile")
    altered.damage=61
    check(not A.valid(altered) and A.compile(altered).is_empty(),"Reject invalid ability")
    for side in [1,-1]:
        var w=W.new(C.defaults())
        w.custom_vfx=FX.new()
        check(w.a.set_ability(profile),"Install ability")
        w.a.pos.x=160-side*25
        w.b.pos.x=160+side*25
        var seen: Dictionary={}
        var initial: float=w.a.pos.x
        var moved: bool=false
        var passed: bool=false
        var visual: bool=false
        for i in range(210):
            w.step(W.DT,{"ability":true},{})
            if w.a.state=="ability":seen[A.phase_at(profile,w.a.t)]=true
            if (w.a.pos.x-initial)*side>10:moved=true
            if (w.b.pos.x-w.a.pos.x)*side<0:passed=true
            if not w.custom_vfx.active.is_empty():visual=true
        check(seen.has("charge") and seen.has("dash") and seen.has("contact") and seen.has("recovery"),"All four phases")
        check(moved and not passed,"Dash moves toward but not through target")
        check(w.a.attacks_started==1,"Held key does not repeat ability")
        check(w.hits<=1,"Single contact marker")
        check(visual,"Phase VFX emitted")
    # Exact contact outcome independent of the pose/motor test.
    var direct=W.new(C.defaults())
    direct.a.pos.x=100
    direct.b.pos.x=125
    var at: Vector2=direct.b.point("chest")
    var e: Dictionary={"kind":"strike","world_anchor":at,"world_chest":direct.a.point("chest"),"direction":1,"anchor":"hand_near","attack_kind":"ability","attack_time":.74,"chain":1,"ability_damage":24,"ability_reach":19.0,"ability_impact":profile.impact}
    var outcomes: Array=[]
    direct._event(direct.a,direct.b,e,outcomes)
    check(outcomes.size()==1 and outcomes[0].amount==24,"Ability contact damage")
    outcomes.clear()
    e.world_anchor=at+Vector2(50,0)
    direct._event(direct.a,direct.b,e,outcomes)
    check(outcomes.is_empty(),"Ability misses outside reach")

func _run()->void:
    _ability_regression()
    var bank:Dictionary=C.defaults()
    check(C.valid(bank) and bank.size()==12,"Extended bank valid")
    var old:Dictionary=bank.duplicate(true)
    for name in ["cross","heavy","kick","air_strike","hurt_heavy"]:old.erase(name)
    var migrated: Dictionary=C.complete(old)
    check(C.valid(old) and migrated.size()==12,"Old bank migrated")
    for name in C.REQUIRED:
        check(migrated[name]==old[name],"Migration preserves "+name)
    var edited: Dictionary=migrated.duplicate(true)
    edited.cross.events=[]
    check(C.complete(edited).cross.events.is_empty(),"Migration preserves custom cross")
    _check_contact_direction(bank)
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
