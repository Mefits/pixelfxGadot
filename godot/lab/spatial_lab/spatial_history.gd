extends RefCounted
## S[t] = before command t. Ring is bounded; only confirmed events leave
## the speculative timeline, at most once. No networking side effects.
var sim
var slots:Array=[]
var confirmed:int=-1
func _init(driver,capacity:int):
    assert(capacity>0)
    sim=driver
    slots.resize(capacity)
    confirmed=sim.tick-1

func advance(cmd:Dictionary)->bool:
    var t:int=sim.tick
    if t-confirmed>slots.size():return false
    var state:Dictionary={"tick":t,"before":sim.save(),"cmd":cmd.duplicate(true)}
    sim.step(cmd)
    state.events=sim.events.duplicate(true)
    slots[t%slots.size()]=state
    return true

func correct(t:int,cmd:Dictionary)->bool:
    var end:int=sim.tick
    if t<=confirmed or t>=end or end-t>slots.size():return false
    var first:Dictionary=slots[t%slots.size()]
    if first.tick!=t:return false
    if first.cmd==cmd:return true
    var commands:Array=[]
    for n in range(t,end):
        commands.append(cmd.duplicate(true) if n==t else slots[n%slots.size()].cmd.duplicate(true))
    if not sim.restore(first.before):return false
    for input in commands:
        if not advance(input):return false
    return true

func confirm_through(t:int)->Array:
    var out:Array=[]
    var last:int=mini(t,sim.tick-1)
    for n in range(confirmed+1,last+1):
        out.append_array(slots[n%slots.size()].events.duplicate(true))
    confirmed=maxi(confirmed,last)
    return out
