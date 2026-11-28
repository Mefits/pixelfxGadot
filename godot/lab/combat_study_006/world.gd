extends "res://lab/combat_study_005/world.gd"
const Control=preload("res://lab/combat_study_006/control.gd")
const RETREAT_SPEED:float=.85
const RETREAT_CAP:float=90.
var directions:Array=[false,false]
var retreat_steps:Array=[0.,0.]
var retreat_budget:float=0.
var retreat_distance:Array=[0.,0.]
var retreat_ticks:Array=[0,0]

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2):
    super(gap,stop_enabled,profile)

func normalize(slot:int,cmd:Dictionary)->Dictionary:
    # Named commands remain supported for the existing ability/AI adapter.
    if cmd.has("edge"):
        return Control.decode(cmd,airborne(slot),actors[slot].stun>0)
    var c:Dictionary=cmd.duplicate(true)
    if bool(c.get("forward",false)) and bool(c.get("back",false)):
        c.forward=false
        c.back=false
    return c

func step(left:Dictionary,right:Dictionary)->void:
    var a:Dictionary=normalize(0,left)
    var b:Dictionary=normalize(1,right)
    directions=[bool(a.get("back",false)),bool(b.get("back",false))]
    retreat_steps=[0.,0.]
    retreat_budget=maxf(0.,(RETREAT_CAP-(root_x(1)-root_x(0)))*.5)
    super.step(a,b)

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    command=super.motion_command(slot,action,command)
    var s:Dictionary=actors[slot]
    # This hook executes after the base world has selected a permitted action
    # and before stun/recovery decrement. No attack/guard/stun cancel.
    if directions[slot] and action.is_empty() and s.remaining==0 and s.stun==0 and not s.guard and not airborne(slot) and not command.has("action"):
        command.speed=0.
        command.travel_limit=0.
        retreat_steps[slot]=minf(RETREAT_SPEED,retreat_budget)
    return command

func advance_positions()->void:
    super.advance_positions()
    for i in 2:
        var distance:float=retreat_steps[i]
        if distance>0.:
            actors[i].x=float(actors[i].x)-facing(i)*distance
            retreat_distance[i]+=distance
            retreat_ticks[i]+=1

func save()->PackedByteArray:
    # Directions/budgets are recomputed from the next command, not state.
    return var_to_bytes([6,super.save(),retreat_distance,retreat_ticks])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==6)
    super.restore(s[1])
    retreat_distance=s[2]
    retreat_ticks=s[3]
