extends RefCounted
## Isolated fixed-tick command driver, not a match or network transport.
## The accepted Training controller remains unmodified.
const Round=preload("res://lab/spatial_lab/spatial_roundhouse.gd")
const Training=preload("res://lab/training_control.gd")
const VERSION:int=1
var actor=Round.new()
var tick:int=0
var serial:int=0
var events:Array=[]
var last_rejected:bool=false

func step(cmd:Dictionary)->void:
    events=[]
    last_rejected=false
    if cmd.has("tuning"):actor.configure(cmd.tuning)
    if cmd.get("start",false) and not actor.active:
        var source=Training.new()
        for i in int(cmd.get("run_ticks",0)):source.step(1,true)
        var yaw:int=0 if actor.player.current.is_empty() else actor.player.rig.yaw_units
        if actor.begin(source,yaw):
            serial+=1
        else:last_rejected=true
    elif actor.active:
        var fired_before:bool=actor.fired
        var q:Dictionary=actor.step()
        last_rejected=not q.accepted
        if q.accepted and actor.fired and not fired_before:
            # Diagnostic event only, identity is stable through resimulation.
            events.append({"tick":tick,"serial":serial,"phase":actor.age,"hit":actor.diagnostic.hit})
    tick+=1

func save()->PackedByteArray:
    return var_to_bytes([VERSION,tick,serial,last_rejected,actor.checkpoint()])

func restore(bytes:PackedByteArray)->bool:
    var s=bytes_to_var(bytes)
    if not s is Array or s.size()!=5 or s[0]!=VERSION:return false
    tick=s[1]
    serial=s[2]
    last_rejected=s[3]
    actor.load_checkpoint(s[4])
    events=[]
    return true

# Exact bytes are useful within one build; no network serialization claim.
func exact_hash()->String:
    return save().hex_encode().sha256_text()

# Diagnostic 1e-4 grid (not quantized simulation). Stable sorted key order,
# type tags preserve integers vs floats and avoid ambiguous container order.
static func canonical(v,scale:float=10000.):
    match typeof(v):
        TYPE_FLOAT:return ["f",roundi(v*scale)]
        TYPE_VECTOR2:return ["v2",canonical(v.x,scale),canonical(v.y,scale)]
        TYPE_VECTOR3:return ["v3",canonical(v.x,scale),canonical(v.y,scale),canonical(v.z,scale)]
        TYPE_QUATERNION:return ["q",canonical(v.x,scale),canonical(v.y,scale),canonical(v.z,scale),canonical(v.w,scale)]
        TYPE_BASIS:return ["b",canonical(v.x,scale),canonical(v.y,scale),canonical(v.z,scale)]
        TYPE_DICTIONARY:
            var keys:Array=v.keys()
            keys.sort()
            var pairs:Array=[]
            for k in keys:pairs.append([k,canonical(v[k],scale)])
            return ["d",pairs]
        TYPE_ARRAY:
            var items:Array=[]
            for item in v:items.append(canonical(item,scale))
            return ["a",items]
        _:return v

func grid_hash()->String:
    return JSON.stringify(canonical([VERSION,tick,serial,last_rejected,actor.checkpoint()])).sha256_text()
