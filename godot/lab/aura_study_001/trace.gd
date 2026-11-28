extends RefCounted
## Identical deterministic command trace for every visual candidate.
const GAP:float=84.
const TICKS:int=180
static func commands(t:int)->Array:
    var a:Dictionary={"forward":t>=8 and t<35}
    var b:Dictionary={"forward":t>=25 and t<47}
    if t==50:a.action="cross"
    if t==84:b.action="cross"
    if t>=115 and t<146:a.forward=true
    if t==150:a.action="kick"
    return [a,b]
