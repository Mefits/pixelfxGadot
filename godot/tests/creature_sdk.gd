extends SceneTree
const CAT=preload("res://addons/creature/catalog.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
var failures:int=0
var validator=VALID.new()
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
func has_code(report:Dictionary,code:String,path:String)->bool:
    for e in report.errors:
        if e.code==code and e.path==path:return true
    return false
func _run()->void:
    var entries:Dictionary={}
    var folder:String="/tmp/sdk-fixtures" if OS.has_feature("linux") else "user://sdk-fixtures"
    DirAccess.make_dir_recursive_absolute(folder)
    for e in CAT.builtins():
        entries[e.id]=e
        var report:Dictionary=validator.validate(e)
        check(report.ok,"SDK builtin "+e.id+" "+JSON.stringify(report.errors))
        var roundtrip:Variant=JSON.parse_string(JSON.stringify(e,"  ",true,true))
        check(validator.validate(roundtrip).ok,"SDK roundtrip "+e.id)
        var f:=FileAccess.open(folder.path_join(e.id+".json"),FileAccess.WRITE)
        check(f!=null,"Fixture write "+e.id)
        if f!=null:f.store_string(JSON.stringify(e,"  ",true,true))
    var invalid:Dictionary=entries.creature_tentacled.duplicate(true)
    invalid.payload.leg_count=7
    check(has_code(validator.validate(invalid),"schema.enum","/payload/leg_count"),"Precise leg error")
    invalid=entries.fx_5.duplicate(true)
    invalid.payload.layers[0].duraton=1
    check(has_code(validator.validate(invalid),"schema.unknown","/payload/layers/0/duraton"),"Typo diagnosed")
    invalid=entries.fx_5.duplicate(true)
    invalid.payload.layers[0].curves={"size":[[0,1],[.5,4],[.4,5],[1,2]]}
    check(has_code(validator.validate(invalid),"curve.order","/payload/layers/0/curves/size/2/0"),"Curve order")
    invalid=entries.ability_electric.duplicate(true)
    invalid.payload.phases[1].id="charge"
    check(has_code(validator.validate(invalid),"ability.phase_order","/payload/phases/1/id"),"Phase order")
    invalid=entries.anim_strike.duplicate(true)
    invalid.payload.clip.keys[1].t=0
    check(has_code(validator.validate(invalid),"clip.time","/payload/clip/keys/1/t"),"Clip ordering")
    invalid=entries.physical_grab.duplicate(true)
    invalid.payload.damage=1.5
    check(has_code(validator.validate(invalid),"schema.type","/payload/damage"),"Integer damage")
    check(not validator.validate(null).ok and not validator.validate([]).ok and not validator.validate({}).ok,"Malformed documents rejected")
    check(not validator.validate_file("user://does-not-exist-sdk.json").ok,"Missing file")
    var report:Dictionary=validator.compatibility(entries.creature_quadruped,entries.physical_grab)
    check(has_code(report,"compat.tentacle","/creature/payload/tentacles"),"Grab compatibility")
    report=validator.compatibility(entries.creature_tentacled,entries.physical_grab)
    check(report.ok and report.warnings.size()==1,"Compatible grab with reach warning")
    check(not validator.compatibility(entries.creature_biped,entries.physical_claw).ok,"Claw excludes biped")
    check(not validator.compatibility(entries.creature_crawler,entries.physical_leap).ok,"Leap requires limbs")
    check(not validator.compatibility(entries.creature_quadruped,entries.ability_electric).ok,"Engine mismatch")
    print("SDK failures: ",failures,"; canonical fixtures: ",entries.size())
    quit(0 if failures==0 else 1)
