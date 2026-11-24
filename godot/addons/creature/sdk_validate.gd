extends RefCounted
## Canonical SDK authoring diagnostics. Structural schema + engine semantics.
## Does not replace the permissive legacy loader. Paths are JSON Pointers.
const API=preload("res://addons/creature/kit_api.gd")
const PATH="res://addons/creature/template.schema.json"
const VERSION="0.35"
const LIMIT=64
var errors:Array=[]
var warnings:Array=[]
var schema:Dictionary={}

func _issue(path:String,code:String,message:String)->void:
    if errors.size()<LIMIT:errors.append({"path":path,"code":code,"message":message})

func _child(path:String,key:Variant)->String:
    return path+"/"+str(key).replace("~","~0").replace("/","~1")

func _type(v:Variant,kind:String)->bool:
    match kind:
        "object":return v is Dictionary
        "array":return v is Array
        "string":return v is String
        "boolean":return v is bool
        "number":return (v is float or v is int) and is_finite(float(v))
        "integer":return (v is float or v is int) and is_finite(float(v)) and float(v)==floorf(float(v))
    return false

func _equal(a:Variant,b:Variant)->bool:
    if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
    return typeof(a)==typeof(b) and a==b

func _matches(s:Variant,v:Variant)->bool:
    var before:Array=errors
    errors=[]
    _walk(s,v,"")
    var ok:bool=errors.is_empty()
    errors=before
    return ok

func _walk(s:Variant,v:Variant,path:String)->void:
    if errors.size()>=LIMIT:return
    if s is bool:
        if not s:_issue(path,"schema.forbidden","Value is not allowed here")
        return
    if not s is Dictionary:return
    if s.has("$ref"):
        _walk(schema["$defs"][str(s["$ref"]).get_file()],v,path)
        return
    if s.has("type") and not _type(v,s.type):
        _issue(path,"schema.type","Expected "+str(s.type))
        return
    if s.has("const") and not _equal(v,s["const"]):_issue(path,"schema.const","Expected "+str(s["const"]))
    if s.has("enum"):
        var found:bool=false
        for allowed in s["enum"]:
            if _equal(v,allowed):found=true;break
        if not found:_issue(path,"schema.enum","Allowed values: "+str(s["enum"]))
    if v is float or v is int:
        for key in ["minimum","maximum","exclusiveMinimum"]:
            if not s.has(key):continue
            if (key=="minimum" and v<s[key]) or (key=="maximum" and v>s[key]) or (key=="exclusiveMinimum" and v<=s[key]):
                _issue(path,"schema.range",key+" "+str(s[key]))
    if v is String:
        if v.length()<int(s.get("minLength",0)) or v.length()>int(s.get("maxLength",1000000)):_issue(path,"schema.length","String length out of range")
        if s.has("pattern"):
            var regex:=RegEx.new()
            regex.compile(s.pattern)
            if regex.search(v)==null:_issue(path,"schema.pattern","Expected "+str(s.pattern))
    if v is Array:
        if v.size()<int(s.get("minItems",0)) or v.size()>int(s.get("maxItems",1000000)):
            _issue(path,"schema.length","Array length out of range")
        else:
            var prefix:Array=s.get("prefixItems",[])
            for i in range(v.size()):
                if i<prefix.size():_walk(prefix[i],v[i],_child(path,i))
                elif s.has("items"):_walk(s["items"],v[i],_child(path,i))
    if v is Dictionary:
        var props:Dictionary=s.get("properties",{})
        for key in s.get("required",[]):
            if not v.has(key):_issue(_child(path,key),"schema.required","Required field is missing")
        for key in v:
            if props.has(key):_walk(props[key],v[key],_child(path,key))
            elif s.has("additionalProperties"):
                if s.additionalProperties is bool and not s.additionalProperties:_issue(_child(path,key),"schema.unknown","Unknown field; check spelling")
                elif s.additionalProperties is Dictionary:_walk(s.additionalProperties,v[key],_child(path,key))
    for part in s.get("allOf",[]):_walk(part,v,path)
    if s.has("if"):
        if _matches(s["if"],v):
            if s.has("then"):_walk(s["then"],v,path)
        elif s.has("else"):_walk(s["else"],v,path)
    if s.has("not") and _matches(s["not"],v):_issue(path,"schema.forbidden","Conflicting field for selected type")

func _curves(p:Dictionary,path:String)->void:
    for i in range(p.layers.size()):
        var l:Dictionary=p.layers[i]
        for channel in l.get("curves",{}):
            var pts:Array=l.curves[channel]
            var base:String=path+"/layers/%d/curves/"%i+channel
            if float(pts[0][0])!=0 or float(pts[-1][0])!=1:_issue(base,"curve.endpoints","Curve must begin at 0 and end at 1")
            for j in range(1,pts.size()):
                if float(pts[j][0])-float(pts[j-1][0])<.001-1e-8:_issue(base+"/%d/0"%j,"curve.order","Times must increase by at least 0.001")

func _semantic(e:Dictionary)->void:
    var p:Dictionary=e.payload
    match e.kind:
        "vfx":_curves(p,"/payload")
        "animation":
            var c:Dictionary=p.clip
            var last:float=-1
            for i in range(c.keys.size()):
                var t:float=float(c.keys[i].t)
                if t<=last or t>float(c.duration):_issue("/payload/clip/keys/%d/t"%i,"clip.time","Key times must increase within duration")
                last=t
            var count:int=0
            for i in range(c.events.size()):
                var marker:Dictionary=c.events[i]
                if float(marker.t)>float(c.duration):_issue("/payload/clip/events/%d/t"%i,"clip.time","Marker exceeds clip duration")
                if marker.kind=="vfx":
                    count+=1
                    _curves(marker.preset,"/payload/clip/events/%d/preset"%i)
            if count>32:_issue("/payload/clip/events","clip.vfx_limit","At most 32 VFX markers")
        "ability":
            if p.get("engine","")!="physical":
                for i in range(p.phases.size()):
                    var phase:Dictionary=p.phases[i]
                    var base:String="/payload/phases/%d"%i
                    if phase.id!=API.ABILITY.PHASES[i]:_issue(base+"/id","ability.phase_order","Expected "+API.ABILITY.PHASES[i])
                    var prior:float=0
                    for j in range(phase.get("keys",[]).size()):
                        var u:float=float(phase.keys[j].u)
                        if u<=prior:_issue(base+"/keys/%d/u"%j,"ability.key_order","Normalized keys must strictly increase")
                        prior=u
                    if phase.has("effect"):_curves(phase.effect,base+"/effect")
                    for j in range(phase.get("accents",[]).size()):_curves(phase.accents[j].effect,base+"/accents/%d/effect"%j)
                if p.has("impact"):_curves(p.impact,"/payload/impact")
        "creature":
            var a:Dictionary=API.ANATOMY.normalize(p)
            if a.limbs and int(a.leg_count)<2:_issue("/payload/leg_count","anatomy.support","Enabled legs require at least two")
            if a.type=="biped" and int(a.leg_count)!=2:_issue("/payload/leg_count","anatomy.biped","Biped requires two legs")

func validate(value:Variant)->Dictionary:
    errors=[]
    warnings=[]
    if schema.is_empty():
        var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if not raw is Dictionary:
            _issue("","sdk.schema_missing","Install template.schema.json with the SDK")
            return _result()
        schema=raw
    _walk(schema,value,"")
    if errors.is_empty():
        _semantic(value)
        if errors.is_empty() and not API.valid(value):_issue("/payload","runtime.invalid","Engine rejected payload; consult the runtime validator")
    return _result()

func _result()->Dictionary:
    return {"sdk_version":VERSION,"ok":errors.is_empty(),"errors":errors.duplicate(true),"warnings":warnings.duplicate(true)}

func validate_file(path:String)->Dictionary:
    errors=[]
    warnings=[]
    var f:=FileAccess.open(path,FileAccess.READ)
    if f==null or f.get_length()>8*1024*1024:
        _issue("","file.read","Missing, unreadable or larger than 8 MiB")
        return _result()
    var parser:=JSON.new()
    if parser.parse(f.get_as_text())!=OK:
        _issue("","file.json","Line %d: %s"%[parser.get_error_line(),parser.get_error_message()])
        return _result()
    return validate(parser.data)

func compatibility(anatomy:Dictionary,ability:Dictionary)->Dictionary:
    var a:Dictionary=validate(anatomy)
    var b:Dictionary=validate(ability)
    errors=[]
    warnings=[]
    if not a.ok or anatomy.get("kind")!="creature":_issue("/creature","compat.anatomy","Expected valid creature template")
    if not b.ok or ability.get("kind")!="ability" or ability.get("payload",{}).get("engine")!="physical":_issue("/ability","compat.engine","Expected physical ability template; humanoid uses fighter rig")
    if errors.is_empty():
        var p:Dictionary=API.ANATOMY.normalize(anatomy.payload)
        var kind:String=ability.payload.type
        match kind:
            "grab":
                if int(p.tentacles)==0:_issue("/creature/payload/tentacles","compat.tentacle","Grab requires at least one tentacle")
            "claw":
                if not p.limbs or p.type=="biped" or int(p.leg_count)<2:_issue("/creature/payload/leg_count","compat.claw","Claw needs front support limbs on non-biped")
            "leap":
                if not p.limbs:_issue("/creature/payload/limbs","compat.leap","Leap requires enabled limbs")
            "grow":
                if int(p.tail)>=12:_issue("/creature/payload/tail","compat.tail_limit","Tail already at maximum 12")
        if kind=="grab" and float(ability.payload.reach)>float(p.tentacle_length)*int(p.tentacle_segments):
            warnings.append({"path":"/ability/payload/reach","code":"compat.reach_clamped","message":"Actual reach is limited by physical tentacle length"})
    return _result()
