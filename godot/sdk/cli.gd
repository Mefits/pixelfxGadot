extends SceneTree
## Machine-facing CLI. Commands use JSON and return explicit exit status.
const CAT=preload("res://addons/creature/catalog.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
const EXP=preload("res://addons/creature/kit_export.gd")
const API=preload("res://addons/creature/kit_api.gd")
var validator=VALID.new()
func _initialize()->void:call_deferred("_run")
func _reply(ok:bool,data:Dictionary,code:int=1)->void:
    var result:Dictionary={"ok":ok,"sdk_version":"0.35"}
    result.merge(data,true)
    print("CREATURE_SDK "+JSON.stringify(result,"",true,true))
    quit(0 if ok else code)
func _fail(message:String)->void:
    _reply(false,{"error":message},2)
func _load_json(path:String)->Dictionary:
    var f:=FileAccess.open(path,FileAccess.READ)
    if f==null or f.get_length()>8*1024*1024:return {"ok":false,"error":"Unreadable or >8 MiB: "+path}
    var parser:=JSON.new()
    if parser.parse(f.get_as_text())!=OK:return {"ok":false,"error":"JSON line %d: %s"%[parser.get_error_line(),parser.get_error_message()]}
    return {"ok":true,"value":parser.data}
func _save(value:Variant,path:String)->Error:
    if FileAccess.file_exists(path):return ERR_ALREADY_EXISTS
    var f:=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return FileAccess.get_open_error()
    f.store_string(JSON.stringify(value,"  ",true,true)+"\n")
    return f.get_error()
func _find(id:String)->Dictionary:
    for e in CAT.builtins():
        if e.id==id:return e.duplicate(true)
    return {}
func _resolve(input:String)->Dictionary:
    var entry:Dictionary=_find(input)
    if not entry.is_empty():return entry
    var data:Dictionary=_load_json(input)
    return data.value if data.ok and data.value is Dictionary else {}
# RFC 7396 merge patch, including removal with null and replacement of arrays.
func _merge(value:Variant,patch:Variant)->Variant:
    if not patch is Dictionary:return patch
    var out:Dictionary=value.duplicate(true) if value is Dictionary else {}
    for k in patch:
        if patch[k]==null:out.erase(k)
        else:out[k]=_merge(out.get(k),patch[k])
    return out
func _run()->void:
    var args:PackedStringArray=OS.get_cmdline_user_args()
    if args.is_empty() or args[0]=="help":
        _reply(true,{"commands":["list [kind]","show ID","clone ID OUTPUT.json","patch INPUT.json PATCH.json OUTPUT.json","validate INPUT.json","compat CREATURE.json ABILITY.json","export INPUT.json OUTPUT.zip","simulate CREATURE.json ABILITY.json|- [ticks]"]})
        return
    match args[0]:
        "list":
            if args.size()>2:_fail("list [kind]");return
            if args.size()==2 and not args[1] in CAT.KINDS:_fail("Unknown kind");return
            var out:Array=[]
            for e in CAT.builtins():
                if args.size()==1 or e.kind==args[1]:out.append({"id":e.id,"name":e.name,"kind":e.kind})
            _reply(true,{"templates":out})
        "show":
            if args.size()!=2:_fail("show ID");return
            var e:Dictionary=_find(args[1])
            if e.is_empty():_fail("Unknown template");return
            _reply(true,{"template":e})
        "clone","patch":
            var e:Dictionary={}
            var output:String=""
            if args[0]=="clone":
                if args.size()!=3:_fail("clone ID OUTPUT.json");return
                e=_find(args[1])
                output=args[2]
                if e.is_empty():_fail("Unknown template");return
                e.source="authored"
            else:
                if args.size()!=4:_fail("patch INPUT.json PATCH.json OUTPUT.json");return
                var input:Dictionary=_load_json(args[1])
                var patch:Dictionary=_load_json(args[2])
                if not input.ok or not patch.ok or not input.value is Dictionary or not patch.value is Dictionary:_fail("Expected two JSON objects");return
                e=_merge(input.value,patch.value)
                output=args[3]
            var report:Dictionary=validator.validate(e)
            if not report.ok:_reply(false,{"report":report});return
            var err:Error=_save(e,output)
            if err!=OK:_fail(error_string(err));return
            _reply(true,{"path":output,"report":report})
        "validate":
            if args.size()!=2:_fail("validate INPUT.json");return
            var report:Dictionary=validator.validate_file(args[1])
            _reply(report.ok,{"report":report})
        "compat":
            if args.size()!=3:_fail("compat CREATURE ABILITY");return
            var report:Dictionary=validator.compatibility(_resolve(args[1]),_resolve(args[2]))
            _reply(report.ok,{"report":report})
        "export":
            if args.size()!=3:_fail("export INPUT OUTPUT.zip");return
            var e:Dictionary=_resolve(args[1])
            var report:Dictionary=validator.validate(e)
            if not report.ok:_reply(false,{"report":report});return
            var err:Error=EXP.export_entry(e,args[2])
            if err!=OK:_fail(error_string(err));return
            _reply(true,{"path":args[2]})
        "simulate":
            if args.size()<3 or args.size()>4:_fail("simulate CREATURE ABILITY|- [ticks]");return
            if args.size()==4 and (not args[3].is_valid_int() or int(args[3])<120 or int(args[3])>3600):_fail("ticks must be 120..3600");return
            _simulate(_resolve(args[1]),{} if args[2]=="-" else _resolve(args[2]),args[2]!="-",int(args[3]) if args.size()==4 else 600)
        _:_fail("Unknown command "+args[0])
func _simulate(e:Dictionary,ability:Dictionary,with_ability:bool,ticks:int)->void:
    var report:Dictionary=validator.validate(e)
    if not report.ok or e.get("kind")!="creature":_reply(false,{"report":report,"error":"Expected creature"});return
    if with_ability:
        report=validator.compatibility(e,ability)
        if not report.ok:_reply(false,{"report":report});return
    var boxes:Array[Rect2]=[Rect2(-5000,200,10000,200)]
    var c=API.create_creature(e,Vector2(100,150),boxes)
    var target:Dictionary={}
    var start:Vector2=c.body.point("front")
    var started:bool=false
    var events:Array=[]
    var max_pen:float=0
    var max_error:float=0
    var finite:bool=true
    var max_support:int=0
    var old_tail:int=c.tail_count
    if with_ability and not API.attach_ability(ability,c):_fail("Could not attach ability");return
    for i in range(ticks):
        if with_ability and i>=120 and not started and c.grounded:
            var front:Vector2=c.body.point("front")
            var distance:float=29 if ability.payload.type=="grab" else (22 if ability.payload.type=="claw" else 35)
            target={"id":"sdk","p":front+Vector2(distance,0),"r":8.0,"hp":100}
            c.attack.targets.assign([target])
            started=c.special.begin(c,target)
        var axis:float=0.0 if with_ability or i<120 else 1.0
        c.advance(1.0/120.0,axis,false)
        for event in c.special.drain_events():
            if events.size()<64:
                var data:Dictionary=event.duplicate(true)
                if data.get("p") is Vector2:data.p=[data.p.x,data.p.y]
                events.append(data)
        finite=finite and c.body.finite()
        if not finite:break
        max_pen=maxf(max_pen,c.body.penetration())
        max_error=maxf(max_error,c.body.max_error)
        max_support=maxi(max_support,c.limbs.support_count)
    var end:Vector2=c.body.point("front")
    var ok:bool=finite and max_pen<.1 and (started if with_ability else end.x>start.x+10)
    _reply(ok,{"ticks":ticks,"finite":finite,"max_penetration":max_pen,"max_constraint_error":max_error,"max_support":max_support,"displacement":[end.x-start.x,end.y-start.y],"ability_started":started,"hits":c.special.hits+c.attack.hit_count,"target_hp":target.get("hp",100),"tail_delta":c.tail_count-old_tail,"events":events,"anatomy":c.anatomy_snapshot()})
