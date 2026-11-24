extends RefCounted
## Unified data-only catalogue. No simulation or native renderer on scan.
const SPECIAL=preload("res://addons/creature/physical_ability.gd")
const ANATOMY=preload("res://addons/creature/anatomy.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const C=preload("res://addons/creature/clips.gd")
const A=preload("res://addons/creature/ability.gd")
const UI=preload("res://lab/ui_ru.gd")
const FOLDER="user://creature_library"
const HANDOFF="creature_library_open"
const KINDS=["vfx","animation","ability","creature"]
const LABELS={"vfx":"Эффекты","animation":"Анимации","ability":"Способности","creature":"Существа"}
const ROUTES={"vfx":"vfx_workshop","animation":"pose_workshop","ability":"combat_lab","creature":"physics_lab"}
static func entry(id:String,kind:String,name:String,payload:Dictionary,source:String="builtin")->Dictionary:
    return {"schema":1,"id":id,"kind":kind,"name":name,"payload":payload.duplicate(true),"source":source}

static func valid(e:Variant)->bool:
    if not e is Dictionary or e.get("schema")!=1 or not e.get("kind") in KINDS or not e.get("name") is String or e.name.strip_edges().is_empty() or e.name.length()>120 or not e.get("payload") is Dictionary:return false
    var p: Dictionary=e.payload
    match e.kind:
        "vfx":return P.valid(p)
        "ability":return A.valid(p) or SPECIAL.valid(p)
        "animation":
            if not p.get("slot") in C.NAMES or not p.get("clip") is Dictionary:return false
            var bank: Dictionary=C.defaults()
            bank[p.slot]=p.clip
            return C.valid(bank)
        "creature":
            return ANATOMY.valid(p)
    return false

static func builtins()->Array:
    var out:Array=[]
    for i in range(12):
        var p:Dictionary=P.demo(i)
        p.name=UI.label(p.name)
        out.append(entry("fx_%d"%i,"vfx",p.name,p))
    var bank:Dictionary=C.defaults()
    for slot in C.NAMES:out.append(entry("anim_"+slot,"animation",UI.label(slot),{"slot":slot,"clip":bank[slot]}))
    out.append(entry("ability_dash","ability","Импульсный рывок",A.defaults()))
    out.append(entry("ability_electric","ability","Электрический прорыв",A.electric_demo()))
    for a in SPECIAL.templates():out.append(entry("physical_"+a.type,"ability",a.name,a))
    for a in ANATOMY.templates():out.append(entry("creature_"+a.type,"creature",a.name,a))
    return out

static func safe_id(id:String)->bool:
    if not id.begins_with("copy_") or id.length()>80:return false
    for ch in id:
        if not ch in "abcdefghijklmnopqrstuvwxyz0123456789_":return false
    return true

static func read_entry(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>8*1024*1024:return {}
    var value:Variant=JSON.parse_string(file.get_as_text())
    if not valid(value):return {}
    return value

static func scan()->Array:
    var out:Array=builtins()
    var dir:=DirAccess.open(FOLDER)
    if dir!=null:
        for file in dir.get_files():
            if not file.ends_with(".json"):continue
            var id:String=file.get_basename()
            if not safe_id(id):continue
            var value:Dictionary=read_entry(FOLDER.path_join(file))
            if value.is_empty():continue
            value.id=id
            value.source="library"
            out.append(value)
    var presets:=DirAccess.open(P.FOLDER)
    if presets!=null:
        for file in presets.get_files():
            if not file.ends_with(".json"):continue
            var path:String=P.FOLDER.path_join(file)
            var f:=FileAccess.open(path,FileAccess.READ)
            if f==null or f.get_length()>8*1024*1024:continue
            var p:Dictionary=P.load_preset(path)
            if not p.is_empty():out.append(entry("preset:"+file,"vfx",p.name,p,"saved"))
    for i in range(2):
        var path:String=C.SAVE_PATH if i==0 else C.SECOND_PATH
        if not FileAccess.file_exists(path):continue
        var f:=FileAccess.open(path,FileAccess.READ)
        if f==null or f.get_length()>8*1024*1024:continue
        var data:Variant=JSON.parse_string(f.get_as_text())
        if not C.valid(data):continue
        var bank:Dictionary=C.complete(data)
        for slot in C.NAMES:out.append(entry("saved_%d_"%i+slot,"animation",UI.label(slot)+" · Боец "+str(i+1),{"slot":slot,"clip":bank[slot]},"saved"))
    if FileAccess.file_exists(A.PATH):
        var f:=FileAccess.open(A.PATH,FileAccess.READ)
        if f!=null and f.get_length()<=8*1024*1024:
            var profile:Variant=JSON.parse_string(f.get_as_text())
            if A.valid(profile):out.append(entry("saved_ability","ability",profile.name,profile,"saved"))
    return out

static func save_copy(value:Dictionary,replace_id:String="")->Dictionary:
    if not valid(value):return {}
    var id:String=replace_id
    DirAccess.make_dir_recursive_absolute(FOLDER)
    if id.is_empty():
        id="copy_%d_%d"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
        while FileAccess.file_exists(FOLDER.path_join(id+".json")):id+="_1"
    elif not safe_id(id) or not FileAccess.file_exists(FOLDER.path_join(id+".json")):return {}
    if not safe_id(id):return {}
    var result:Dictionary=entry(id,value.kind,value.name,value.payload,"library")
    var path:String=FOLDER.path_join(id+".json")
    var temporary:String=path+".partial_"+str(Time.get_ticks_usec())
    var f:=FileAccess.open(temporary,FileAccess.WRITE)
    if f==null:return {}
    f.store_string(JSON.stringify(result,"  ",true,true))
    var err:Error=f.get_error()
    f.close()
    if err!=OK or read_entry(temporary).is_empty():
        DirAccess.remove_absolute(temporary)
        return {}
    if DirAccess.rename_absolute(temporary,path)!=OK:
        DirAccess.remove_absolute(temporary)
        return {}
    return result

static func import_file(path:String)->Dictionary:
    var e:Dictionary=read_entry(path)
    if not e.is_empty():return save_copy(e)
    if not FileAccess.file_exists(path):return {}
    var f:=FileAccess.open(path,FileAccess.READ)
    if f==null or f.get_length()>8*1024*1024:return {}
    var data:Variant=JSON.parse_string(f.get_as_text())
    if P.valid(data):return save_copy(entry("","vfx",data.name,data))
    if A.valid(data) or SPECIAL.valid(data):return save_copy(entry("","ability",data.name,data))
    if ANATOMY.valid(data):
        var a:Dictionary=ANATOMY.normalize(data)
        return save_copy(entry("","creature",a.name,a))
    return {}

static func matches(e:Dictionary,kind:String,query:String)->bool:
    return (kind.is_empty() or kind==e.kind) and (query.strip_edges().is_empty() or (e.name+" "+LABELS[e.kind]+" "+e.id).to_lower().contains(query.strip_edges().to_lower()))

static func consume(tree:SceneTree,kind:String)->Dictionary:
    if not tree.has_meta(HANDOFF):return {}
    var e:Variant=tree.get_meta(HANDOFF)
    tree.remove_meta(HANDOFF)
    return e.duplicate(true) if valid(e) and e.kind==kind else {}

static func save_draft(e:Dictionary,payload:Dictionary,name:String="")->Dictionary:
    var value:Dictionary=e.duplicate(true)
    value.payload=payload.duplicate(true)
    if not name.strip_edges().is_empty():value.name=name.strip_edges()
    return save_copy(value,str(e.id) if e.get("source")=="library" else "")

static func route(e:Dictionary)->String:
    if e.kind=="ability" and SPECIAL.valid(e.payload):return "physics_lab"
    return ROUTES[e.kind]

## Library management only. Saved legacy banks and builtins remain read-only.
const TRASH="user://creature_library_trash"
static func rename_copy(id:String,new_name:String)->Dictionary:
    if not safe_id(id):return {}
    var e:Dictionary=read_entry(FOLDER.path_join(id+".json"))
    if e.is_empty():return {}
    e.name=new_name.strip_edges()
    if e.kind in ["vfx","ability","creature"]:e.payload.name=e.name
    return save_copy(e,id)

static func trash_copy(id:String)->Error:
    if not safe_id(id):return ERR_INVALID_PARAMETER
    var source:String=FOLDER.path_join(id+".json")
    if read_entry(source).is_empty():return ERR_FILE_NOT_FOUND
    var err:Error=DirAccess.make_dir_recursive_absolute(TRASH)
    if err!=OK:return err
    var target:String=TRASH.path_join(id+".json")
    if FileAccess.file_exists(target):return ERR_ALREADY_EXISTS
    return DirAccess.rename_absolute(source,target)
