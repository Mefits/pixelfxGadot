extends RefCounted
const TICKS:int=115
const CAST_TICK:int=12
const MISS_GAP:float=96.
static func commands(t:int,scenario:String,mirror:bool=false)->Array:
    var a:Dictionary={}
    var b:Dictionary={}
    if t==CAST_TICK:a.action="avatar_fist" if scenario!="control" else "cross"
    if scenario=="block":b.guard=true
    if scenario=="trade" and t==CAST_TICK:b.action="avatar_fist"
    if scenario=="moving" and t>=CAST_TICK-6 and t<CAST_TICK+5:b.forward=true
    return [b,a] if mirror else [a,b]
