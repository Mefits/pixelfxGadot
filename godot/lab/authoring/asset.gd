extends RefCounted
const Motion=preload("res://lab/hybrid091/motion.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Clips=preload("res://addons/creature/clips.gd")
const VFX=preload("res://addons/pixelfx/composer/preset.gd")
const DIR="res://lab/authoring/motions/"
const FOLDER="user://motion_authoring/"
const IDS=["sprint","jab","feint"]
const JOINTS=["hand_near","hand_far","elbow_near","elbow_far","foot_near","foot_far","knee_near","knee_far"]
const CHANNELS=["chest","head","shoulder_turn","shoulder_near","elbow_near","shoulder_far","elbow_far"]
const LEG_CHANNELS=["hips","pelvis_turn","thigh_near","knee_near","foot_pitch_near","thigh_far","knee_far","foot_pitch_far"]
const EVENT_ANCHORS=["hips","chest","head","shoulder_near","elbow_near","hand_near","shoulder_far","elbow_far","hand_far","thigh_near","knee_near","foot_near","thigh_far","knee_far","foot_far"]
const EASING=["linear","smooth","accelerate","hold","snap"]
const FIX="res://tests/fixtures/body_raster/full_058/"
static var run_clip:Dictionary
static var guard:Dictionary

static func read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

static func number(v:Variant,lo:float,hi:float)->bool:
    return (v is float or v is int) and is_finite(v) and v>=lo and v<=hi

static func normalise(d:Dictionary)->Dictionary:
    var out:Dictionary=d.duplicate(true)
    if out.get("kind")=="action":
        out.version=2
        out.fps=int(out.get("fps",60))
        out.easing=str(out.get("easing","linear"))
        out.loop=bool(out.get("loop",false))
        for k in out.get("keys",[]):
            if not k.has("root"):k.root=[0.,0.]
    return out

static func problem(d:Dictionary)->String:
    if not d.get("version") in [1,2] or not d.get("id") is String or not d.id.is_valid_identifier() or not d.get("name") is String:return "Версия или имя движения"
    if not d.get("goals") is Array or d.goals.size()>64:return "Список целей (до 64)"
    for g in d.goals:
        if not g is Dictionary or not g.get("joint") in JOINTS:return "Неизвестный сустав"
        if not g.get("xy") is Array or g.xy.size()!=2 or not number(g.xy[0],-128,128) or not number(g.xy[1],-128,128):return "Координаты вне диапазона"
        if not number(g.get("center"),0,1) or not number(g.get("width"),.01,1) or not number(g.get("weight"),0,1) or not number(g.get("priority"),0,9):return "Параметры цели"
        if not g.get("clock") in (["cycle","swing_near","swing_far"] if d.get("kind")=="gait" else ["action"]):return "Фаза цели"
    if d.get("kind")=="gait":
        return "" if number(d.get("speed"),1,1.85) and number(d.get("arm_sweep",94.),70,115) and number(d.get("flight_width",5.),2,7) else "Параметры бега"
    if d.get("kind")!="action" or not number(d.get("duration"),.05,10) or not d.get("keys") is Array or d.keys.size()<2 or d.keys.size()>600:return "Длительность или ключи"
    if not number(d.get("fps",60),1,60) or float(d.get("fps",60))!=floorf(float(d.get("fps",60))) or not d.get("easing","linear") in EASING or not d.get("loop",false) is bool:return "Частота кадров, интерполяция или цикл"
    var last:float=-1.
    var mask:Array=[]
    for k in d.keys:
        if not k is Dictionary or not number(k.get("t"),0,d.duration) or k.t<=last or not k.get("angles") is Dictionary or k.angles.is_empty():return "Порядок поз"
        if not k.get("root",[0.,0.]) is Array or k.get("root",[0.,0.]).size()!=2 or not number(k.get("root",[0.,0.])[0],-40,40) or not number(k.get("root",[0.,0.])[1],-40,40):return "Перемещение корня"
        if k.has("easing") and not k.easing in EASING:return "Интерполяция ключа"
        if mask.is_empty():mask=k.angles.keys()
        if mask.size()!=k.angles.size():return "Каналы поз"
        for id in mask:
            if (not id in CHANNELS and not id in LEG_CHANNELS) or not number(k.angles.get(id),-360,360):return "Канал позы"
        last=k.t
    if d.keys[0].t!=0 or not is_equal_approx(last,d.duration):return "Границы движения"
    var release=d.get("release",{})
    if not release is Dictionary:return "Фазы опоры"
    for side in release:
        var knots=release[side]
        if not side in ["near","far"] or not knots is Array or knots.size()!=4:return "Фаза освобождения ноги"
        for i in 4:
            if not number(knots[i],0,1) or (i>0 and knots[i]<=knots[i-1]):return "Порядок фаз ноги"
        for part in ["thigh_","knee_","foot_pitch_"]:
            if not mask.has(part+side):return "Пропущен канал ноги"
    if not d.get("events") is Array or d.events.size()>32:return "Список маркеров"
    for e in d.events:
        if not e is Dictionary or not number(e.get("t"),0,d.duration) or not e.get("kind") in ["strike","charge","cast","vfx"] or not e.get("anchor") in EVENT_ANCHORS:return "Маркер"
        if e.kind=="strike" and not (str(e.anchor).begins_with("hand_") or str(e.anchor).begins_with("foot_")):return "Strike должен быть привязан к кисти или стопе"
        if e.kind=="vfx" and not VFX.valid(e.get("preset")):return "Пресет VFX"
    if d.get("loop",false):
        for e in d.events:
            if e.kind=="strike":return "Циклическое действие не может содержать боевой контакт"
    return ""

static func persist(d:Dictionary)->Error:
    d=normalise(d)
    if problem(d)!="":return ERR_INVALID_DATA
    var dir:=DirAccess.open("user://")
    var err:=dir.make_dir_recursive("motion_authoring")
    if err!=OK:return err
    var dest:String=FOLDER+d.id+".json"
    var f:=FileAccess.open(dest+".tmp",FileAccess.WRITE)
    if not f:return FileAccess.get_open_error()
    f.store_string(JSON.stringify(d,"  ",true,true))
    f.flush()
    err=f.get_error()
    f.close()
    if err!=OK:return err
    return DirAccess.rename_absolute(dest+".tmp",dest)

static func build(d:Dictionary,hz:int)->Dictionary:
    assert(problem(d)=="")
    var goals:Array=[]
    for index in d.goals.size():
        var g:Dictionary=d.goals[index].duplicate()
        g.xy=Vector2(g.xy[0],g.xy[1])
        g.order=index
        goals.append(g)
    goals.sort_custom(func(a,b):return a.priority>b.priority if a.priority!=b.priority else a.order<b.order)
    var canonical=JSON.parse_string(JSON.stringify(d,"",true,true))
    var signature:=JSON.stringify(canonical,"",true,true).sha256_text()
    var out={"goals":goals,"signature":signature,"bank":{},"kind":d.kind}
    if d.kind=="action":
        var keys:Array=[]
        for k in d.keys:keys.append({"t":k.t,"pose":{"angles":k.angles,"root":k.get("root",[0.,0.])},"easing":k.get("easing",d.get("easing","linear"))})
        var clip={"keys":keys,"easing":d.get("easing","linear"),"events":d.events,"duration":d.duration,"loop":d.get("loop",false),"authored_root":d.get("version",1)==2}
        var release:Dictionary={}
        for side in d.get("release",{}):
            release[side]=[]
            for knot in d.release[side]:release[side].append(knot*d.duration*60.)
        var channels:Array=(CHANNELS+LEG_CHANNELS).filter(func(id):return d.keys[0].angles.has(id))
        out.bank[d.id]=Motion.compile(clip,0,ceili(d.duration*60.-.000001),channels,hz,Body.make_rig() if not release.is_empty() else null,release)
    return out

static func legacy_clip_valid(c:Variant)->bool:
    if not c is Dictionary or not number(c.get("duration"),.05,10) or not c.get("loop") is bool or not c.get("keys") is Array or c.keys.size()<2 or c.keys.size()>600 or not c.get("events") is Array or not c.get("easing","smooth") in EASING:return false
    var last:float=-1.
    for k in c.keys:
        if not k is Dictionary or not number(k.get("t"),0,c.duration) or k.t<=last or not k.get("pose") is Dictionary:return false
        if k.has("easing") and not k.easing in EASING:return false
        last=k.t
        var p:Dictionary=k.pose
        if not p.get("angles") is Dictionary or not p.get("root") is Array or p.root.size()!=2:return false
        for id in p.angles:
            if not id in CHANNELS+LEG_CHANNELS or not number(p.angles[id],-360,360):return false
        for v in p.root:
            if not number(v,-40,40):return false
    for e in c.events:
        if not e is Dictionary or not number(e.get("t"),0,c.duration) or not e.get("kind") in ["strike","charge","cast","vfx"] or not e.get("anchor") in EVENT_ANCHORS:return false
        if e.kind=="strike" and not (str(e.anchor).begins_with("hand_") or str(e.anchor).begins_with("foot_")):return false
        if e.kind=="vfx" and not VFX.valid(e.get("preset")):return false
    return is_equal_approx(float(c.keys[0].t),0.) and is_equal_approx(float(last),float(c.duration))

static func legacy_clip_to_action(c:Dictionary,id:String,label:String,fps:int=30)->Dictionary:
    if not legacy_clip_valid(c) or not id.is_valid_identifier():return {}
    var channels:Array=[]
    for k in c.keys:
        for channel in k.pose.angles:
            if not channels.has(channel):channels.append(channel)
    if channels.is_empty():return {}
    var release:Dictionary={}
    for side in ["near","far"]:
        var has_leg:bool=channels.has("thigh_"+side) or channels.has("knee_"+side) or channels.has("foot_pitch_"+side)
        if not has_leg:continue
        release[side]=[0.,.02,.98,1.]
        for channel in ["thigh_"+side,"knee_"+side,"foot_pitch_"+side]:
            if not channels.has(channel):channels.append(channel)
    var keys:Array=[]
    for k in c.keys:
        var angles:Dictionary={}
        for channel in channels:angles[channel]=float(k.pose.angles.get(channel,0.))
        keys.append({"t":float(k.t),"angles":angles,"root":[float(k.pose.root[0]),float(k.pose.root[1])],"easing":k.get("easing",c.get("easing","smooth"))})
    var d:Dictionary={"version":2,"id":id,"name":label,"kind":"action","duration":float(c.duration),"fps":clampi(fps,1,60),"easing":str(c.get("easing","smooth")),"loop":bool(c.loop),"keys":keys,"events":c.events.duplicate(true),"goals":[]}
    if not release.is_empty():d.release=release
    return d if problem(d)=="" else {}

static func import_legacy_bank(bank:Dictionary,prefix:String="u",fps:int=30)->Array:
    var source:Dictionary=bank.get("bank",bank)
    var result:Array=[]
    for name in source:
        var c:Variant=source[name]
        if not legacy_clip_valid(c):continue
        var id:String=prefix+"_"+str(name)
        var d:Dictionary=legacy_clip_to_action(c,id,str(name),fps)
        if not d.is_empty():result.append(d)
    return result

static func available()->Array:
    var ids:Array=IDS.duplicate()
    var folder:=DirAccess.open(FOLDER)
    if folder:
        for file in folder.get_files():
            var id:String=file.get_basename()
            if file.ends_with(".json") and id.is_valid_identifier() and not ids.has(id):ids.append(id)
    var result:Array=[]
    for id in ids:
        var d:=read(FOLDER+id+".json")
        if d.get("id")!=id or problem(d)!="":d=read(DIR+id+".json")
        if d.get("id")==id and problem(d)=="":result.append(d)
    return result

static func player(d:Dictionary,hz:int):
    return ensemble(d if d.kind=="gait" else {},[d] if d.kind=="action" else [],hz)

# Use one rig and one action calendar. Immutable programs are selected by
# the kernel's current action, including when a new command interrupts it.
static func ensemble(gait_doc:Dictionary,actions:Array,hz:int,base_bank:Dictionary={}):
    if run_clip.is_empty():
        run_clip=read(FIX+"run053a_C.json").payload.clip
        guard=read(FIX+"combo052a2_B.json").payload.clip.keys[0].pose.angles.duplicate()
        for id in guard.keys():
            if not id in CHANNELS:guard.erase(id)
        for id in guard:guard[id]=Grid.scalar(guard[id])
    var bank:=base_bank.duplicate()
    var programs:Dictionary={}
    var signatures:Array=[]
    if not gait_doc.is_empty():
        var gait_asset:=build(gait_doc,hz)
        programs[""]=gait_asset.goals
        signatures.append(gait_asset.signature)
    for d in actions:
        var asset:=build(d,hz)
        bank.merge(asset.bank,true)
        programs[d.id]=asset.goals
        signatures.append(asset.signature)
    var k=Kernel.new(Body.make_rig(),run_clip,bank,guard,hz)
    k.gait.arm_sweep=gait_doc.get("arm_sweep",94.)
    k.gait.flight_width=gait_doc.get("flight_width",5.)
    k.art={"programs":programs,"signature":JSON.stringify(signatures).sha256_text()}
    return k
