extends RefCounted
const Motion=preload("res://lab/hybrid091/motion.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const DIR="res://lab/authoring/motions/"
const FOLDER="user://motion_authoring/"
const IDS=["sprint","jab","feint"]
const JOINTS=["hand_near","hand_far","elbow_near","elbow_far","foot_near","foot_far"]
const CHANNELS=["chest","head","shoulder_turn","shoulder_near","elbow_near","shoulder_far","elbow_far"]
const FIX="res://tests/fixtures/body_raster/full_058/"
static var run_clip:Dictionary
static var guard:Dictionary

static func read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

static func number(v:Variant,lo:float,hi:float)->bool:
    return (v is float or v is int) and is_finite(v) and v>=lo and v<=hi

static func problem(d:Dictionary)->String:
    if d.get("version")!=1 or not d.get("id") is String or not d.id.is_valid_identifier() or not d.get("name") is String:return "Версия или имя движения"
    if not d.get("goals") is Array or d.goals.size()>64:return "Список целей (до 64)"
    for g in d.goals:
        if not g is Dictionary or not g.get("joint") in JOINTS:return "Неизвестный сустав"
        if not g.get("xy") is Array or g.xy.size()!=2 or not number(g.xy[0],-128,128) or not number(g.xy[1],-128,128):return "Координаты вне диапазона"
        if not number(g.get("center"),0,1) or not number(g.get("width"),.01,1) or not number(g.get("weight"),0,1) or not number(g.get("priority"),0,9):return "Параметры цели"
        if not g.get("clock") in (["cycle","swing_near","swing_far"] if d.get("kind")=="gait" else ["action"]):return "Фаза цели"
    if d.get("kind")=="gait":
        return "" if number(d.get("speed"),1,1.85) and number(d.get("arm_sweep",94.),70,115) and number(d.get("flight_width",5.),2,7) else "Параметры бега"
    if d.get("kind")!="action" or not number(d.get("duration"),.05,5) or not d.get("keys") is Array or d.keys.size()<2 or d.keys.size()>256:return "Длительность или ключи"
    var last:float=-1.
    var mask:Array=[]
    for k in d.keys:
        if not k is Dictionary or not number(k.get("t"),0,d.duration) or k.t<=last or not k.get("angles") is Dictionary or k.angles.is_empty():return "Порядок поз"
        if mask.is_empty():mask=k.angles.keys()
        if mask.size()!=k.angles.size():return "Каналы поз"
        for id in mask:
            if not id in CHANNELS or not number(k.angles.get(id),-360,360):return "Канал позы"
        last=k.t
    if d.keys[0].t!=0 or not is_equal_approx(last,d.duration):return "Границы движения"
    if not d.get("events") is Array or d.events.size()>32:return "Список маркеров"
    for e in d.events:
        if not e is Dictionary or not number(e.get("t"),0,d.duration) or e.get("kind")!="strike" or not e.get("anchor") in ["hand_near","hand_far","foot_near","foot_far"]:return "Маркер"
    return ""

static func persist(d:Dictionary)->Error:
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
        for k in d.keys:keys.append({"t":k.t,"pose":{"angles":k.angles,"root":[0,0]}})
        var clip={"keys":keys,"easing":"linear","events":d.events,"duration":d.duration,"loop":false}
        out.bank[d.id]=Motion.compile(clip,0,ceili(d.duration*60.-.000001),d.keys[0].angles.keys(),hz)
    return out

static func player(d:Dictionary,hz:int):
    if run_clip.is_empty():
        run_clip=read(FIX+"run053a_C.json").payload.clip
        guard=read(FIX+"combo052a2_B.json").payload.clip.keys[0].pose.angles.duplicate()
        for id in guard.keys():
            if not id in CHANNELS:guard.erase(id)
        for id in guard:guard[id]=Grid.scalar(guard[id])
    var asset:=build(d,hz)
    var k=Kernel.new(Body.make_rig(),run_clip,asset.bank,guard,hz)
    k.gait.arm_sweep=d.get("arm_sweep",94.)
    k.gait.flight_width=d.get("flight_width",5.)
    k.art=asset
    return k
