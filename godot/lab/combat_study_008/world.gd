extends "res://lab/combat_study_007/world.gd"
## A baseline; B shorter grounded strike recovery; C B + mobility.
## No startup, contact, stun, damage, parry, air or cancel-rule changes.
const TEMPO_NAMES=["A Control","B Faster recovery","C Recovery + mobility"]
const GROUND_STRIKES=["jab","cross","kick","pulse"]
var tempo:int=0
var original_cross:Dictionary={}

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2,variant:int=0,enabled:bool=true):
    super(gap,stop_enabled,profile,enabled)
    assert(variant in [0,1,2])
    tempo=variant
    original_cross=bank.cross.duplicate(true)
    if tempo>0:
        for id in GROUND_STRIKES:
            var src:Dictionary=bank[id]
            var mark:int=int(src.markers.keys()[0])
            var old_last:int=src.frames.size()-1
            var recovery:int=maxi(2,roundi(float(old_last-mark)*.65))
            var dst:Dictionary=src.duplicate(true)
            for key in ["frames","roots","feet"]:
                var sequence:Array=[]
                for i in range(mark+1):sequence.append(src[key][i])
                for i in range(1,recovery+1):
                    var f:int=roundi(lerpf(float(mark),float(old_last),float(i)/recovery))
                    sequence.append(src[key][f])
                dst[key]=sequence
            bank[id]=dst

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    command=super.motion_command(slot,action,command)
    if tempo==2:
        # Only a permitted neutral move, not dash/attack/air or a cancel.
        if action.is_empty() and float(command.speed)>0.:
            command.speed=1.55
        if retreat_steps[slot]>0.:
            retreat_steps[slot]=minf(1.25,retreat_budget)
    return command

func save()->PackedByteArray:
    return var_to_bytes([8,tempo,super.save()])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==8 and s[1]==tempo)
    super.restore(s[2])
