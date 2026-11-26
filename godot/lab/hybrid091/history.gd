extends RefCounted
## Bounded prediction history for one kernel. A match must checkpoint both
## fighters and resolve simultaneous contacts at its own world boundary.
var player
var slots:Array=[]
var confirmed:int
func _init(kernel,capacity:int):
    assert(capacity>0)
    player=kernel
    confirmed=player.tick-1
    slots.resize(capacity)

func advance(cmd:Dictionary)->bool:
    var t:int=player.tick
    if t-confirmed>slots.size():return false
    var slot={"tick":t,"before":player.save(),"cmd":cmd.duplicate(true)}
    player.step(cmd)
    slot.events=player.events.duplicate(true)
    slots[t%slots.size()]=slot
    return true

func correct(t:int,cmd:Dictionary)->bool:
    var end:int=player.tick
    if t<=confirmed or t>=end or end-t>slots.size():return false
    var first:Dictionary=slots[t%slots.size()]
    if first.tick!=t:return false
    if first.cmd==cmd:return true
    player.restore(first.before)
    for n in range(t,end):
        var input:Dictionary=cmd if n==t else slots[n%slots.size()].cmd
        advance(input)
    return true

# Presentation can consume confirmed events once, even after repeated replay.
func confirm_through(t:int)->Array:
    var out:Array=[]
    var last:=mini(t,player.tick-1)
    for n in range(confirmed+1,last+1):
        out.append_array(slots[n%slots.size()].events.duplicate(true))
    confirmed=maxi(confirmed,last)
    return out
