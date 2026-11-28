extends RefCounted
## A reversible candidate layout. Raw edges are not permissions.
## Opposite directions and conflicting attack edges resolve to neutral.
const LIGHT:int=1
const HEAVY:int=2
const SKILL:int=4
const MOBILITY:int=8
const DEFENSE:int=16
const MASK:int=31
static func decode(raw:Dictionary,air:bool,hurt:bool)->Dictionary:
    var f:bool=bool(raw.get("forward",false))
    var b:bool=bool(raw.get("back",false))
    var cmd:Dictionary={"forward":f and not b,"back":b and not f,"guard":bool(raw.get("guard",false))}
    var edge:int=int(raw.get("edge",0)) & MASK
    var mod:bool=bool(raw.get("modifier",false))
    # Exactly one edge. Simultaneous ambiguous presses do not choose a move
    # based on platform-dependent event arrival order.
    match edge:
        LIGHT:cmd.action="air_cross" if air else ("launch" if mod else "jab")
        HEAVY:cmd.action="slam" if air else ("kick" if mod else "cross")
        SKILL:cmd.action="air_pulse" if air else ("dash" if mod else "pulse")
        MOBILITY:cmd.action="chase"
        DEFENSE:
            if air and hurt:cmd.escape=true
            elif not air:cmd.action="parry"
    return cmd
